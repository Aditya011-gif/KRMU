import '../models/analysis_model.dart';
import '../models/land_details_model.dart';

/// Pre-built mock data scenarios for testing the Fraud Risk Engine.
///
/// **How the fraud rules work:**
/// ┌──────┬──────────────────────────────────────────────────────┐
/// │ R₁   │ landArea > 50 (2× district avg of 25)               │
/// │ R₂   │ NDVI < 0.35  AND  cropQualityGrade contains Grade A │
/// │ R₃   │ loanStatus contains "default" or "overdue"          │
/// │ R₄   │ landArea > 0  AND  ownershipDocuments is empty       │
/// └──────┴──────────────────────────────────────────────────────┘
///
/// Use [MockFraudData.loadScenario] in the dashboard to inject a scenario.
class MockFraudData {
  MockFraudData._();

  // ═══════════════════════════════════════════════════════════
  //  SCENARIO 1 — Clean Farmer (FRS = 0, Low Risk)
  //  No rules triggered. Everything looks legitimate.
  // ═══════════════════════════════════════════════════════════
  static final cleanAnalysis = AnalysisModel(
    id: 'mock-clean-001',
    userId: 'mock-user',
    latitude: 29.6857,
    longitude: 76.9905,
    ndviValue: 0.72, // Healthy vegetation — won't trigger R₂
    soilType: 'Alluvial',
    landClass: 'Cropland',
    weatherIndex: 0.8,
    marketIndex: 0.7,
    agriScore: 720,
    riskCategory: 'Low',
    mlPredictions: MLPrediction(
      cropQuality: 'Grade B', // Not Grade A — won't trigger R₂
      cropHealthScore: 82,
      riskLevel: 'Low',
      ndviTrend: 'Increasing',
      ndviTrendDescription: 'Steady improvement over last 3 months',
      confidence: {'crop_quality': 0.91, 'risk_level': 0.88},
    ),
    scoreBreakdown: ScoreBreakdown(
      ndviScore: 18,
      soilScore: 15,
      landClassScore: 16,
      weatherScore: 14,
      marketScore: 12,
      ndviRaw: 0.72,
      soilType: 'Alluvial',
      landClass: 'Cropland',
    ),
    createdAt: DateTime.now(),
  );

  static final cleanLandDetails = LandDetailsModel(
    id: 'mock-land-clean-001',
    userId: 'mock-user',
    latitude: 29.6857,
    longitude: 76.9905,
    landArea: 12.0, // Below 50 — won't trigger R₁
    areaUnit: 'Acres',
    cropType: 'Wheat',
    cropQualityGrade: 'Grade B',
    currentSeason: 'Rabi',
    pastLoanAmount: 150000,
    loanProvider: 'SBI',
    loanStatus: 'Active', // Not overdue — won't trigger R₃
    loanDocuments: ['loan_sanction_letter.pdf'],
    ownershipDocuments: [
      'land_patta.pdf',
      'mutation_certificate.pdf',
    ], // Has docs — won't trigger R₄
    createdAt: DateTime.now(),
  );

  // ═══════════════════════════════════════════════════════════
  //  SCENARIO 2 — Moderate Risk (FRS = 35, Moderate Risk)
  //  Triggers: R₁ (Yield Anomaly) + R₃ (Repayment Delays)
  //  Weights: 20 + 15 = 35
  // ═══════════════════════════════════════════════════════════
  static final moderateAnalysis = AnalysisModel(
    id: 'mock-moderate-002',
    userId: 'mock-user',
    latitude: 29.9695,
    longitude: 76.8783,
    ndviValue: 0.58, // Above 0.35 — won't trigger R₂
    soilType: 'Loamy',
    landClass: 'Cropland',
    weatherIndex: 0.6,
    marketIndex: 0.5,
    agriScore: 480,
    riskCategory: 'Medium',
    mlPredictions: MLPrediction(
      cropQuality: 'Grade B',
      cropHealthScore: 60,
      riskLevel: 'Medium',
      ndviTrend: 'Stable',
      ndviTrendDescription: 'No significant changes in vegetation',
      confidence: {'crop_quality': 0.78, 'risk_level': 0.73},
    ),
    scoreBreakdown: ScoreBreakdown(
      ndviScore: 14,
      soilScore: 12,
      landClassScore: 10,
      weatherScore: 8,
      marketScore: 7,
      ndviRaw: 0.58,
      soilType: 'Loamy',
      landClass: 'Cropland',
    ),
    createdAt: DateTime.now(),
  );

  static final moderateLandDetails = LandDetailsModel(
    id: 'mock-land-moderate-002',
    userId: 'mock-user',
    latitude: 29.9695,
    longitude: 76.8783,
    landArea: 65.0, // > 50 → triggers R₁ (Yield Anomaly)
    areaUnit: 'Acres',
    cropType: 'Rice',
    cropQualityGrade: 'Grade B',
    currentSeason: 'Kharif',
    pastLoanAmount: 500000,
    loanProvider: 'PNB',
    loanStatus: 'Overdue', // → triggers R₃ (Repayment Delays)
    loanDocuments: ['loan_agreement.pdf'],
    ownershipDocuments: [
      'khasra_number.pdf',
      'fard.pdf',
    ], // Has docs — won't trigger R₄
    createdAt: DateTime.now(),
  );

  // ═══════════════════════════════════════════════════════════
  //  SCENARIO 3 — High Risk (FRS = 85, High Risk)
  //  Triggers: R₁ + R₂ + R₄  (Manual Review Required)
  //  Weights: 20 + 25 + 40 = 85
  //  R₄ alone forces manual review.
  // ═══════════════════════════════════════════════════════════
  static final highRiskAnalysis = AnalysisModel(
    id: 'mock-high-003',
    userId: 'mock-user',
    latitude: 29.3909,
    longitude: 76.9635,
    ndviValue: 0.18, // < 0.35 — contributes to R₂
    soilType: 'Sandy',
    landClass: 'Barren/Fallow',
    weatherIndex: 0.3,
    marketIndex: 0.4,
    agriScore: 210,
    riskCategory: 'High',
    mlPredictions: MLPrediction(
      cropQuality: 'Grade A', // Grade A + low NDVI → triggers R₂
      cropHealthScore: 25,
      riskLevel: 'High',
      ndviTrend: 'Declining',
      ndviTrendDescription:
          'Sharp decline. Possible crop failure or false reporting.',
      confidence: {'crop_quality': 0.45, 'risk_level': 0.92},
    ),
    scoreBreakdown: ScoreBreakdown(
      ndviScore: 4,
      soilScore: 6,
      landClassScore: 3,
      weatherScore: 5,
      marketScore: 4,
      ndviRaw: 0.18,
      soilType: 'Sandy',
      landClass: 'Barren/Fallow',
    ),
    createdAt: DateTime.now(),
  );

  static final highRiskLandDetails = LandDetailsModel(
    id: 'mock-land-high-003',
    userId: 'mock-user',
    latitude: 29.3909,
    longitude: 76.9635,
    landArea: 80.0, // > 50 → triggers R₁
    areaUnit: 'Acres',
    cropType: 'Sugarcane',
    cropQualityGrade: 'Grade A', // Grade A + low NDVI → triggers R₂
    currentSeason: 'Rabi',
    pastLoanAmount: 1200000,
    loanProvider: 'HDFC',
    loanStatus: 'Active',
    loanDocuments: ['loan_notice.pdf'],
    ownershipDocuments: [], // Empty! → triggers R₄ (Land Record Discrepancy)
    createdAt: DateTime.now(),
  );

  // ═══════════════════════════════════════════════════════════
  //  SCENARIO 4 — Maximum Fraud (FRS = 100, High Risk)
  //  ALL 4 rules triggered. Manual review required.
  //  Weights: 20 + 25 + 15 + 40 = 100
  // ═══════════════════════════════════════════════════════════
  static final maxFraudAnalysis = AnalysisModel(
    id: 'mock-max-004',
    userId: 'mock-user',
    latitude: 28.9931,
    longitude: 77.0151,
    ndviValue: 0.10, // Very low → contributes to R₂
    soilType: 'Rocky',
    landClass: 'Industrial',
    weatherIndex: 0.2,
    marketIndex: 0.3,
    agriScore: 95,
    riskCategory: 'Flagged',
    mlPredictions: MLPrediction(
      cropQuality: 'Grade A', // Grade A + low NDVI → triggers R₂
      cropHealthScore: 10,
      riskLevel: 'Critical',
      ndviTrend: 'Declining',
      ndviTrendDescription: 'Industrial land wrongly declared as farmland.',
      confidence: {'crop_quality': 0.30, 'risk_level': 0.97},
    ),
    scoreBreakdown: ScoreBreakdown(
      ndviScore: 2,
      soilScore: 3,
      landClassScore: 1,
      weatherScore: 2,
      marketScore: 2,
      ndviRaw: 0.10,
      soilType: 'Rocky',
      landClass: 'Industrial',
    ),
    createdAt: DateTime.now(),
  );

  static final maxFraudLandDetails = LandDetailsModel(
    id: 'mock-land-max-004',
    userId: 'mock-user',
    latitude: 28.9931,
    longitude: 77.0151,
    landArea: 120.0, // > 50 → triggers R₁
    areaUnit: 'Acres',
    cropType: 'Cotton',
    cropQualityGrade: 'Grade A', // Grade A + low NDVI → triggers R₂
    currentSeason: 'Kharif',
    pastLoanAmount: 2500000,
    loanProvider: 'Bank of Baroda',
    loanStatus: 'Defaulted', // → triggers R₃
    loanDocuments: [],
    ownershipDocuments: [], // Empty → triggers R₄
    createdAt: DateTime.now(),
  );

  // ═══════════════════════════════════════════════════════════
  //  HELPER: Get a scenario by name
  // ═══════════════════════════════════════════════════════════

  /// Available scenario names:
  /// - `'clean'`     → FRS 0  / Low Risk      (0 rules triggered)
  /// - `'moderate'`  → FRS 35 / Moderate Risk  (R₁ + R₃)
  /// - `'high'`      → FRS 85 / High Risk      (R₁ + R₂ + R₄)
  /// - `'max'`       → FRS 100 / High Risk     (all 4 rules)
  static ({AnalysisModel analysis, LandDetailsModel land}) getScenario(
    String name,
  ) {
    switch (name) {
      case 'clean':
        return (analysis: cleanAnalysis, land: cleanLandDetails);
      case 'moderate':
        return (analysis: moderateAnalysis, land: moderateLandDetails);
      case 'high':
        return (analysis: highRiskAnalysis, land: highRiskLandDetails);
      case 'max':
        return (analysis: maxFraudAnalysis, land: maxFraudLandDetails);
      default:
        return (analysis: cleanAnalysis, land: cleanLandDetails);
    }
  }

  /// All available scenario names.
  static const allScenarios = ['clean', 'moderate', 'high', 'max'];

  /// Human-readable labels for each scenario.
  static const scenarioLabels = {
    'clean': '✅ Clean Farmer (FRS 0)',
    'moderate': '⚠️ Moderate Risk (FRS 35)',
    'high': '🔴 High Risk (FRS 85)',
    'max': '💀 Maximum Fraud (FRS 100)',
  };
}
