/// Land analysis data model.

/// ML prediction result from the backend.
class MLPrediction {
  final String cropQuality;
  final int cropHealthScore;
  final String riskLevel;
  final String ndviTrend;
  final String ndviTrendDescription;
  final Map<String, double> confidence;

  MLPrediction({
    required this.cropQuality,
    required this.cropHealthScore,
    required this.riskLevel,
    required this.ndviTrend,
    required this.ndviTrendDescription,
    required this.confidence,
  });

  factory MLPrediction.fromJson(Map<String, dynamic> json) {
    final rawConf = json['confidence'] as Map<String, dynamic>? ?? {};
    final confidence = <String, double>{};
    rawConf.forEach((k, v) => confidence[k] = (v as num).toDouble());

    return MLPrediction(
      cropQuality: json['crop_quality'] ?? 'Unknown',
      cropHealthScore: (json['crop_health_score'] ?? 0).toInt(),
      riskLevel: json['risk_level'] ?? 'Unknown',
      ndviTrend: json['ndvi_trend'] ?? 'Unknown',
      ndviTrendDescription: json['ndvi_trend_description'] ?? '',
      confidence: confidence,
    );
  }
}

class ScoreBreakdown {
  final double ndviScore;
  final double soilScore;
  final double landClassScore;
  final double weatherScore;
  final double marketScore;
  final double? ndviRaw;
  final String? soilType;
  final String? landClass;
  final String? weatherSummary;
  final String? marketSummary;

  ScoreBreakdown({
    required this.ndviScore,
    required this.soilScore,
    required this.landClassScore,
    required this.weatherScore,
    required this.marketScore,
    this.ndviRaw,
    this.soilType,
    this.landClass,
    this.weatherSummary,
    this.marketSummary,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      ndviScore: (json['ndvi_score'] ?? 0).toDouble(),
      soilScore: (json['soil_score'] ?? 0).toDouble(),
      landClassScore: (json['land_class_score'] ?? 0).toDouble(),
      weatherScore: (json['weather_score'] ?? 0).toDouble(),
      marketScore: (json['market_score'] ?? 0).toDouble(),
      ndviRaw: json['ndvi_raw']?.toDouble(),
      soilType: json['soil_type'],
      landClass: json['land_class'],
      weatherSummary: json['weather_summary'],
      marketSummary: json['market_summary'],
    );
  }

  double get totalScore =>
      ndviScore + soilScore + landClassScore + weatherScore + marketScore;
}

class AnalysisModel {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? ndviValue;
  final String? soilType;
  final String? landClass;
  final double? weatherIndex;
  final double? marketIndex;
  final double agriScore;
  final String riskCategory;
  final ScoreBreakdown? scoreBreakdown;
  final List<HeatmapPoint>? heatmapData;
  final String? tileUrl;
  final MLPrediction? mlPredictions;
  final Map<String, dynamic>? weatherDetails;
  final DateTime? createdAt;

  AnalysisModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.ndviValue,
    this.soilType,
    this.landClass,
    this.weatherIndex,
    this.marketIndex,
    required this.agriScore,
    required this.riskCategory,
    this.scoreBreakdown,
    this.heatmapData,
    this.tileUrl,
    this.mlPredictions,
    this.weatherDetails,
    this.createdAt,
  });

  factory AnalysisModel.fromJson(Map<String, dynamic> json) {
    return AnalysisModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      ndviValue: json['ndvi_value']?.toDouble(),
      soilType: json['soil_type'],
      landClass: json['land_class'],
      weatherIndex: json['weather_index']?.toDouble(),
      marketIndex: json['market_index']?.toDouble(),
      agriScore: (json['agri_score'] ?? 0).toDouble(),
      riskCategory: json['risk_category'] ?? 'High',
      scoreBreakdown: json['score_breakdown'] != null
          ? ScoreBreakdown.fromJson(
              json['score_breakdown'] is String
                  ? {}
                  : json['score_breakdown'] as Map<String, dynamic>,
            )
          : null,
      heatmapData: json['heatmap_data'] != null
          ? (json['heatmap_data'] as List)
                .map((e) => HeatmapPoint.fromJson(e))
                .toList()
          : [],
      tileUrl: json['tile_url'],
      mlPredictions: json['ml_predictions'] != null
          ? MLPrediction.fromJson(json['ml_predictions'])
          : null,
      weatherDetails: json['weather_details'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  String get riskLabel {
    switch (riskCategory) {
      case 'Low':
        return '🟢 Low Risk';
      case 'Medium':
        return '🟡 Medium Risk';
      case 'High':
        return '🔴 High Risk';
      case 'Flagged':
        return '🚩 Flagged';
      default:
        return riskCategory;
    }
  }

  int get riskColor {
    switch (riskCategory) {
      case 'Low':
        return 0xFF2E7D32;
      case 'Medium':
        return 0xFFFFA000;
      case 'High':
        return 0xFFD32F2F;
      case 'Flagged':
        return 0xFF9C27B0;
      default:
        return 0xFF757575;
    }
  }
}

class HeatmapPoint {
  final double lat;
  final double lng;
  final double ndvi;

  HeatmapPoint({required this.lat, required this.lng, required this.ndvi});

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      ndvi: (json['ndvi'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'ndvi': ndvi};
}
