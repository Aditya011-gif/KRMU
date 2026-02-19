import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fraud_risk_model.dart';
import '../services/fraud_risk_engine.dart';
import 'analysis_provider.dart';
import 'land_details_provider.dart';

/// Exposes a reactive [FraudRiskResult] that re‑evaluates whenever the
/// analysis or land‑details state changes.
///
/// Usage in widgets:
/// ```dart
/// final fraudRisk = ref.watch(fraudRiskProvider);
/// ```
final fraudRiskProvider = Provider<FraudRiskResult>((ref) {
  final analysisState = ref.watch(analysisProvider);
  final landState = ref.watch(landDetailsProvider);

  // Use the latest analysis result
  final latestAnalysis = analysisState.latestResult;

  // Use the first (most recent) land registration, if any
  final latestLand = landState.registrations.isNotEmpty
      ? landState.registrations.first
      : null;

  return FraudRiskEngine.evaluate(
    analysis: latestAnalysis,
    landDetails: latestLand,
  );
});
