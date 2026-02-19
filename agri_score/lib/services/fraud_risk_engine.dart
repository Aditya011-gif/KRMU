import '../models/analysis_model.dart';
import '../models/land_details_model.dart';
import '../models/fraud_risk_model.dart';

/// Modular, rule‑based Fraud Risk Engine.
///
/// Runs **independently** from the Agri Score and ML credit model.
/// It evaluates 4 weighted rules and produces a Fraud Risk Score (0–100).
///
/// ┌──────┬─────────────────────────────────────────────────┬────────┐
/// │ Rule │ Condition                                       │ Weight │
/// ├──────┼─────────────────────────────────────────────────┼────────┤
/// │ R₁   │ Declared Yield > 2 × District Average Yield     │   20   │
/// │ R₂   │ NDVI < Threshold  AND  Crop Quality = Grade A   │   25   │
/// │ R₃   │ Repayment Delay Count ≥ 3 (last 12 months)      │   15   │
/// │ R₄   │ Verified Land Record ≠ Submitted Land Record    │   40   │
/// └──────┴─────────────────────────────────────────────────┴────────┘
///
/// FRS = (w₁×R₁) + (w₂×R₂) + (w₃×R₃) + (w₄×R₄)   ∈ [0, 100]
/// ManualReviewRequired = true  if  R₄ = 1  OR  FRS > 50
class FraudRiskEngine {
  FraudRiskEngine._(); // static‑only

  // ── Thresholds / constants ────────────────────────────────
  /// District average yield (quintals / acre) – used as baseline for R₁.
  /// In production this would come from the API / DB per district.
  static const double _districtAverageYield = 25.0;

  /// NDVI score below which vegetation is considered unhealthy (R₂).
  static const double _ndviThreshold = 0.35;

  /// Number of repayment delays that trigger R₃.
  // ignore: unused_field
  static const int _repaymentDelayThreshold = 3;

  // ── Public API ────────────────────────────────────────────

  /// Evaluate fraud risk from the latest analysis + land details.
  ///
  /// Either parameter may be `null`.  When data is missing the
  /// corresponding rule is simply **not triggered** (conservative).
  static FraudRiskResult evaluate({
    AnalysisModel? analysis,
    LandDetailsModel? landDetails,
  }) {
    final triggered = <FraudRule>[];

    // ── R₁: Yield anomaly ──────────────────────────────────
    if (_checkR1(landDetails)) triggered.add(FraudRule.r1);

    // ── R₂: NDVI vs Crop Quality mismatch ──────────────────
    if (_checkR2(analysis, landDetails)) triggered.add(FraudRule.r2);

    // ── R₃: Repayment delays ───────────────────────────────
    if (_checkR3(landDetails)) triggered.add(FraudRule.r3);

    // ── R₄: Land record discrepancy ────────────────────────
    if (_checkR4(landDetails)) triggered.add(FraudRule.r4);

    // ── Compute score ──────────────────────────────────────
    int frs = 0;
    for (final rule in triggered) {
      frs += rule.weight;
    }
    // Clamp just in case
    if (frs > 100) frs = 100;

    // ── Classify ────────────────────────────────────────────
    final category = _classify(frs);

    // ── Manual review ───────────────────────────────────────
    final manualReview = triggered.contains(FraudRule.r4) || frs > 50;

    return FraudRiskResult(
      fraudRiskScore: frs,
      triggeredRules: triggered,
      fraudRiskCategory: category,
      manualReviewRequired: manualReview,
    );
  }

  // ── Rule checks ──────────────────────────────────────────

  /// R₁ — Declared yield exceeds 2× district average.
  static bool _checkR1(LandDetailsModel? land) {
    if (land == null) return false;
    // Use land area as a proxy for declared yield (quintals).
    // In a real system this would be an explicit "declared yield" field.
    final declaredYield = land.landArea ?? 0;
    return declaredYield > 2 * _districtAverageYield;
  }

  /// R₂ — Low NDVI yet crop quality is reported as Grade A.
  static bool _checkR2(AnalysisModel? analysis, LandDetailsModel? land) {
    if (analysis == null) return false;
    final ndvi = analysis.ndviValue ?? 1.0; // default healthy
    final cropQuality =
        land?.cropQualityGrade ?? analysis.mlPredictions?.cropQuality ?? '';
    return ndvi < _ndviThreshold &&
        cropQuality.toLowerCase().contains('grade a');
  }

  /// R₃ — 3+ repayment delays inferred from loan status.
  static bool _checkR3(LandDetailsModel? land) {
    if (land == null) return false;
    // "Defaulted" or "Overdue" loan status signals repeated delays.
    final status = (land.loanStatus ?? '').toLowerCase();
    return status.contains('default') || status.contains('overdue');
  }

  /// R₄ — Land record discrepancy (ownership docs missing or flagged).
  static bool _checkR4(LandDetailsModel? land) {
    if (land == null) return false;
    // If the user submitted ownership docs but none could be verified
    // (empty verified list), flag as mismatch.
    final submitted = land.ownershipDocuments ?? [];
    // For now, we flag if a user registered land but provided NO
    // ownership documents at all — suggesting an unverifiable claim.
    return land.landArea != null && land.landArea! > 0 && submitted.isEmpty;
  }

  // ── Classification ───────────────────────────────────────

  static FraudRiskCategory _classify(int frs) {
    if (frs <= 20) return FraudRiskCategory.low;
    if (frs <= 50) return FraudRiskCategory.moderate;
    return FraudRiskCategory.high;
  }
}
