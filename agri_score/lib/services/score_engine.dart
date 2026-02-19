/// Agri-Trust Score calculation engine.
///
/// Weighted scoring:
///   - NDVI:               35%
///   - Soil Quality:       25%
///   - Land Classification: 15%
///   - Weather Risk:       15%
///   - Market Risk:        10%
class ScoreEngine {
  static const double weightNdvi = 0.35;
  static const double weightSoil = 0.25;
  static const double weightLand = 0.15;
  static const double weightWeather = 0.15;
  static const double weightMarket = 0.10;

  static const int maxScore = 1000;

  /// Calculate the Agri-Trust Score from all input factors.
  static Map<String, dynamic> calculateAgriScore({
    required double ndvi,
    required String soilType,
    required String landClass,
    required double weatherIndex,
    required double marketIndex,
  }) {
    // ── Component Scores (normalized 0–1) ─────────────────────

    final ndviScore = _scoreNdvi(ndvi);
    final soilScore = _scoreSoil(soilType);
    final landClassScore = _scoreLandClass(landClass);
    final weatherScore = weatherIndex.clamp(0.0, 1.0);
    final marketScore = marketIndex.clamp(0.0, 1.0);

    // ── Weighted Aggregation ──────────────────────────────────

    final rawScore =
        (ndviScore * weightNdvi) +
        (soilScore * weightSoil) +
        (landClassScore * weightLand) +
        (weatherScore * weightWeather) +
        (marketScore * weightMarket);

    // Normalize to 0–1000
    int agriScore = (rawScore * maxScore).round().clamp(0, maxScore);

    // ── Risk Category ─────────────────────────────────────────

    final riskCategory = _categorizeRisk(agriScore);

    // ── Score Breakdown ──────────────────────────────────────

    final breakdown = {
      "ndvi_score": (ndviScore * weightNdvi * maxScore).roundToDouble(),
      "soil_score": (soilScore * weightSoil * maxScore).roundToDouble(),
      "land_class_score": (landClassScore * weightLand * maxScore)
          .roundToDouble(),
      "weather_score": (weatherScore * weightWeather * maxScore)
          .roundToDouble(),
      "market_score": (marketScore * weightMarket * maxScore).roundToDouble(),
      "ndvi_raw": ndvi,
      "soil_type": soilType,
      "land_class": landClass,
      "risk_tier": riskCategory,
      "weather_summary":
          "Weather favorability: ${(weatherIndex * 100).toStringAsFixed(0)}%",
      "market_summary":
          "Market stability: ${(marketIndex * 100).toStringAsFixed(0)}%",
    };

    return {
      "agri_score": agriScore.toDouble(),
      "risk_category": riskCategory,
      "score_breakdown": breakdown,
    };
  }

  static double _scoreNdvi(double ndvi) {
    if (ndvi >= 0.7) return 1.0;
    if (ndvi >= 0.5) return 0.8;
    if (ndvi >= 0.3) return 0.6;
    if (ndvi >= 0.2) return 0.4;
    // Penalize low NDVI heavily (water bodies, barren land)
    if (ndvi >= 0.1) return 0.1;
    return 0.05;
  }

  static double _scoreSoil(String soilType) {
    final lower = soilType.toLowerCase();

    // Premium soils
    if (lower.contains('chernozem')) return 0.95;
    if (lower.contains('phaeozem')) return 0.90;
    if (lower.contains('vertisol')) return 0.88;
    if (lower.contains('black cotton') || lower.contains('regur')) return 0.88;
    if (lower.contains('alluvial')) return 0.85;

    // Good soils
    if (lower.contains('luvisol')) return 0.80;
    if (lower.contains('cambisol')) return 0.78;
    if (lower.contains('fluvisol')) return 0.82;
    if (lower.contains('gleysol')) return 0.70;
    if (lower.contains('red soil')) return 0.72;

    // Moderate/Poor
    if (lower.contains('acrisol')) return 0.60;
    if (lower.contains('ferralsol')) return 0.55;
    if (lower.contains('mixed')) return 0.60;
    if (lower.contains('laterite')) return 0.58;
    if (lower.contains('nitisol')) return 0.65;

    if (lower.contains('leptosol')) return 0.35;
    if (lower.contains('regosol')) return 0.40;
    if (lower.contains('arenosol')) return 0.30;
    if (lower.contains('mountain')) return 0.45;
    if (lower.contains('podzol')) return 0.38;

    return 0.55; // Default moderate
  }

  static double _scoreLandClass(String landClass) {
    final lower = landClass.toLowerCase();

    if (lower.contains('prime') || lower.contains('fertile')) return 0.95;
    if (lower.contains('agricultural')) return 0.80; // General ag land
    if (lower.contains('plantation')) return 0.65;
    if (lower.contains('marginal')) return 0.40;
    if (lower.contains('forest') || lower.contains('wetland')) return 0.25;
    if (lower.contains('urban') || lower.contains('industrial')) return 0.10;
    if (lower.contains('barren') || lower.contains('wasteland')) return 0.05;

    return 0.55; // Default
  }

  static String _categorizeRisk(int score) {
    if (score >= 800) return "Platinum";
    if (score >= 600) return "Gold";
    if (score >= 400) return "Silver";
    return "Bronze";
  }

  /// Get the max eligible loan amount based on the risk category.
  static int getLoanLimit(String category) {
    switch (category) {
      case "Platinum":
        return 1000000; // ₹10,00,000
      case "Gold":
        return 500000; // ₹5,00,000
      case "Silver":
        return 200000; // ₹2,00,000
      case "Bronze":
      default:
        return 50000; // ₹50,000 (Micro-loans)
    }
  }
}
