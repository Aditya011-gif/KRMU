/// Fraud Risk Engine data models.
///
/// These models are independent of the Agri Score and ML credit model.
/// The engine acts as a supervisory integrity layer.

/// The four fraud detection rules.
enum FraudRule {
  r1(
    'R₁ – Yield Anomaly',
    'Declared yield exceeds 2× the district average yield.',
    20,
  ),
  r2(
    'R₂ – NDVI / Quality Mismatch',
    'NDVI score is below threshold while crop quality is Grade A.',
    25,
  ),
  r3(
    'R₃ – Repayment Delays',
    '3 or more repayment delays recorded in the last 12 months.',
    15,
  ),
  r4(
    'R₄ – Land Record Discrepancy',
    'Verified land record does not match the submitted land record.',
    40,
  );

  const FraudRule(this.displayName, this.description, this.weight);

  final String displayName;
  final String description;
  final int weight;
}

/// Risk category derived from the Fraud Risk Score.
enum FraudRiskCategory {
  low('Low', 0xFF2E7D32), // green
  moderate('Moderate', 0xFFFFA000), // orange / amber
  high('High', 0xFFD32F2F); // red

  const FraudRiskCategory(this.label, this.color);

  final String label;
  final int color;
}

/// Output of the Fraud Risk Engine.
class FraudRiskResult {
  final int fraudRiskScore;
  final List<FraudRule> triggeredRules;
  final FraudRiskCategory fraudRiskCategory;
  final bool manualReviewRequired;

  const FraudRiskResult({
    required this.fraudRiskScore,
    required this.triggeredRules,
    required this.fraudRiskCategory,
    required this.manualReviewRequired,
  });

  /// Empty / default result when no data is available.
  static const empty = FraudRiskResult(
    fraudRiskScore: 0,
    triggeredRules: [],
    fraudRiskCategory: FraudRiskCategory.low,
    manualReviewRequired: false,
  );

  bool get isClean => triggeredRules.isEmpty;
}
