import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/analysis_model.dart';
import 'score_engine.dart';

/// API service for direct communication with Supabase and External APIs.
///
/// Replaces the Python backend by performing logic on the client:
/// 1. Fetches data from external APIs (AgroM, OpenWeather, etc)
/// 2. Calculates Agri-Score locally using ScoreEngine
/// 3. Stores results directly to Supabase DB
class ApiService {
  final Dio _dio = Dio();
  final SupabaseClient _supabase = Supabase.instance.client;

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Perform land analysis (Serverless Mode)
  Future<AnalysisModel> analyzeLand({
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('ApiService: Starting analysis for $latitude, $longitude');
    try {
      // 1. Fetch External Data in Parallel
      debugPrint('ApiService: Fetching external data...');
      final results = await Future.wait([
        _fetchNdvi(latitude, longitude),
        _fetchSoil(latitude, longitude),
        _fetchWeather(latitude, longitude),
        _fetchMarket(latitude, longitude),
      ]);
      debugPrint('ApiService: External data fetched.');

      final ndviData = results[0];
      final soilData = results[1];
      final weatherData = results[2];
      final marketData = results[3];

      // 2. Calculate Score
      final scoreResult = ScoreEngine.calculateAgriScore(
        ndvi: (ndviData['ndvi'] as num).toDouble(),
        soilType: soilData['soil_type'] as String,
        landClass: soilData['land_class'] as String,
        weatherIndex: (weatherData['weather_index'] as num).toDouble(),
        marketIndex: (marketData['market_index'] as num).toDouble(),
      );

      // 3. Prepare Data for DB (NO heatmap_data — column doesn't exist)
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final ndviVal = (ndviData['ndvi'] as num).toDouble();

      final analysisData = {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'ndvi_value': ndviVal,
        'soil_type': soilData['soil_type'],
        'land_class': soilData['land_class'],
        'weather_index': weatherData['weather_index'],
        'market_index': marketData['market_index'],
        'agri_score': scoreResult['agri_score'],
        'risk_category': _mapRiskForDb(scoreResult['risk_category']),
        'score_breakdown': scoreResult['score_breakdown'],
      };

      // 4. Save to Supabase
      final response = await _supabase
          .from('land_analysis')
          .insert(analysisData)
          .select()
          .single();

      // 5. Log Audit
      await _logAudit('land_analysis', {'lat': latitude, 'lng': longitude});

      // 6. Generate heatmap LOCALLY (not stored in DB)
      final heatmapPoints = _generateGridHeatmap(latitude, longitude, ndviVal);
      final model = AnalysisModel.fromJson(response);

      // 7. Fetch ML Predictions from Python backend (non-blocking)
      MLPrediction? mlPredictions;
      try {
        final double tempC = (weatherData['temp'] as num?)?.toDouble() ?? 28.0;
        final double rainMm =
            (weatherData['rainfall'] as num?)?.toDouble() ?? 50.0;

        mlPredictions = await fetchMLPredictions(
          ndviCurrent: ndviVal,
          soilType: soilData['soil_type'] as String? ?? 'Mixed Soil',
          rainfallMm: rainMm,
          avgTempC: tempC,
        );
        debugPrint(
          'ApiService: ML predictions received: ${mlPredictions?.cropQuality}',
        );
      } catch (e) {
        debugPrint('ApiService: ML predictions failed (non-blocking): $e');
      }

      return AnalysisModel(
        id: model.id,
        userId: model.userId,
        latitude: model.latitude,
        longitude: model.longitude,
        ndviValue: model.ndviValue,
        soilType: model.soilType,
        landClass: model.landClass,
        weatherIndex: model.weatherIndex,
        marketIndex: model.marketIndex,
        agriScore: model.agriScore,
        riskCategory: model.riskCategory,
        scoreBreakdown: model.scoreBreakdown,
        heatmapData: heatmapPoints
            .map(
              (p) => HeatmapPoint(
                lat: (p['lat'] as num).toDouble(),
                lng: (p['lng'] as num).toDouble(),
                ndvi: (p['ndvi'] as num).toDouble(),
              ),
            )
            .toList(),
        mlPredictions: mlPredictions,
        weatherDetails: weatherData,
        createdAt: model.createdAt,
      );
    } catch (e) {
      debugPrint('Analysis Error: $e');
      rethrow;
    }
  }

  /// Get analysis history
  Future<List<AnalysisModel>> getAnalyses({int limit = 50}) async {
    final response = await _supabase
        .from('land_analysis')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AnalysisModel.fromJson(json))
        .toList();
  }

  /// Get single analysis
  Future<AnalysisModel> getAnalysis(String id) async {
    final response = await _supabase
        .from('land_analysis')
        .select()
        .eq('id', id)
        .single();
    return AnalysisModel.fromJson(response);
  }

  // ── Admin Methods ──────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      // Fetch all farmers for state distribution
      final farmers = await _supabase
          .from('users')
          .select('state')
          .eq('role', 'farmer');

      final totalFarmers = farmers.length;
      final stateDist = <String, int>{};
      for (var f in farmers) {
        final state = f['state'] as String? ?? 'Unknown';
        stateDist[state] = (stateDist[state] ?? 0) + 1;
      }

      // Fetch all analyses for risk distribution and average score
      final analyses = await _supabase
          .from('land_analysis')
          .select('agri_score, risk_category');

      final totalAnalyses = analyses.length;
      double totalScore = 0;
      final riskCounts = {'Low': 0, 'Medium': 0, 'High': 0};

      for (var a in analyses) {
        totalScore += (a['agri_score'] as num).toDouble();
        final risk = a['risk_category'] as String? ?? 'High';
        if (riskCounts.containsKey(risk)) {
          riskCounts[risk] = (riskCounts[risk] ?? 0) + 1;
        } else {
          riskCounts['High'] = (riskCounts['High'] ?? 0) + 1;
        }
      }

      final avgScore = totalAnalyses > 0 ? totalScore / totalAnalyses : 0;

      // Calculate percentages for risk distribution
      final riskPercent = <String, int>{};
      riskCounts.forEach((key, value) {
        riskPercent[key] = totalAnalyses > 0
            ? ((value / totalAnalyses) * 100).round()
            : 0;
      });

      return {
        'total_farmers': totalFarmers,
        'total_analyses': totalAnalyses,
        'average_score': avgScore.round(),
        'flagged_analyses': 0,
        'risk_distribution': riskPercent,
        'state_distribution': stateDist,
      };
    } catch (e) {
      debugPrint('Admin Stats Error: $e');
      return {
        'total_farmers': 0,
        'total_analyses': 0,
        'average_score': 0,
        'risk_distribution': <String, int>{},
        'state_distribution': <String, int>{},
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAdminFarmers({
    String? state,
    String? riskCategory,
    String? search,
    int limit = 50,
  }) async {
    var query = _supabase.from('users').select().eq('role', 'farmer');

    if (state != null) query = query.eq('state', state);
    if (search != null) query = query.ilike('name', '%$search%');

    final response = await query.limit(limit);
    var farmers = (response as List).cast<Map<String, dynamic>>();

    if (riskCategory != null) {
      // enhanced filtering: for each farmer, fetch latest analysis risk
      final filtered = <Map<String, dynamic>>[];
      for (var f in farmers) {
        final analysis = await _supabase
            .from('land_analysis')
            .select('risk_category')
            .eq('user_id', f['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (analysis != null && analysis['risk_category'] == riskCategory) {
          filtered.add(f);
        }
      }
      farmers = filtered;
    }

    return farmers;
  }

  Future<Map<String, dynamic>> getAdminFarmerDetail(String farmerId) async {
    final farmer = await _supabase
        .from('users')
        .select()
        .eq('id', farmerId)
        .single();

    // Get latest analysis for this farmer
    final analyses = await _supabase
        .from('land_analysis')
        .select()
        .eq('user_id', farmerId)
        .order('created_at', ascending: false)
        .limit(10);

    return {
      'profile': farmer,
      'analyses': analyses,
      'stats': {
        'total_scans': analyses.length,
        'avg_score': 0, // Calculate if needed
      },
    };
  }

  // ── ML Prediction API ─────────────────────────────────────

  /// Fetch ML predictions from the Python backend.
  /// Returns null if the backend is unreachable or models aren't trained.
  Future<MLPrediction?> fetchMLPredictions({
    required double ndviCurrent,
    required String soilType,
    double rainfallMm = 50.0,
    double avgTempC = 28.0,
    String cropType = 'Rice',
    String season = 'Kharif',
    double landAreaHectares = 5.0,
  }) async {
    try {
      final baseUrl = kIsWeb ? AppConfig.apiBaseUrlWeb : AppConfig.apiBaseUrl;

      final response = await _dio.post(
        '$baseUrl/predict',
        data: {
          'crop_type': cropType,
          'season': season,
          'land_area_hectares': landAreaHectares,
          'soil_type': soilType,
          'ndvi_current': ndviCurrent,
          'ndvi_30day_avg': ndviCurrent * 0.95,
          'rainfall_mm': rainfallMm,
          'avg_temperature_c': avgTempC,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return MLPrediction.fromJson(response.data);
      }
      debugPrint('ML API returned ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ML API error: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  Future<void> _logAudit(String action, Map<String, dynamic> metadata) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('audit_logs').insert({
        'user_id': userId,
        'action': action,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint("Audit log failed: $e");
    }
  }

  // ── Integrations (Stubbed with Real/Fallback Logic) ────────────────

  Future<Map<String, dynamic>> _fetchNdvi(double lat, double lng) async {
    final appId = AppConfig.agroMonitoringApiKey;

    try {
      debugPrint('ApiService: Fetching NDVI from AgroMonitoring...');

      // Step 1: Clean up ALL existing polygons (free tier limit = ~10)
      try {
        final listResp = await _dio.get(
          'http://api.agromonitoring.com/agro/1.0/polygons',
          queryParameters: {'appid': appId},
        );
        if (listResp.statusCode == 200 && listResp.data is List) {
          for (final p in (listResp.data as List)) {
            try {
              await _dio.delete(
                'http://api.agromonitoring.com/agro/1.0/polygons/${p['id']}',
                queryParameters: {'appid': appId},
              );
            } catch (_) {}
          }
          debugPrint(
            'ApiService: Cleaned ${(listResp.data as List).length} old polygons',
          );
        }
      } catch (e) {
        debugPrint('ApiService: Could not clean polygons: $e');
      }

      // Step 2: Create a fresh polygon (~500m around point)
      const double offset = 0.005;
      final coords = [
        [lng - offset, lat - offset],
        [lng + offset, lat - offset],
        [lng + offset, lat + offset],
        [lng - offset, lat + offset],
        [lng - offset, lat - offset],
      ];

      String? polyId;
      try {
        final createResp = await _dio.post(
          'http://api.agromonitoring.com/agro/1.0/polygons',
          queryParameters: {'appid': appId},
          data: {
            'name': 'ndvi_${DateTime.now().millisecondsSinceEpoch}',
            'geo_json': {
              'type': 'Feature',
              'properties': {},
              'geometry': {
                'type': 'Polygon',
                'coordinates': [coords],
              },
            },
          },
        );
        if (createResp.statusCode == 200 || createResp.statusCode == 201) {
          polyId = createResp.data['id'] as String?;
          debugPrint('ApiService: Created polygon $polyId');
        }
      } catch (e) {
        debugPrint('ApiService: Polygon creation failed: $e');
      }

      if (polyId == null) {
        debugPrint('ApiService: Could not create polygon, using fallback');
        return _generateEstimatedNdvi(lat, lng);
      }

      // Step 3: Search satellite images for the polygon (last 15 days)
      final end = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final start = end - (15 * 86400);

      try {
        final imgResp = await _dio.get(
          'http://api.agromonitoring.com/agro/1.0/image/search',
          queryParameters: {
            'polyid': polyId,
            'start': start,
            'end': end,
            'appid': appId,
          },
        );

        if (imgResp.statusCode == 200 && imgResp.data is List) {
          final images = imgResp.data as List;
          debugPrint('ApiService: Found ${images.length} satellite images');

          if (images.isNotEmpty) {
            // Get NDVI stats from the most recent image
            final latest = images.last;
            final statsUrl = latest['stats']?['ndvi'] as String?;

            if (statsUrl != null) {
              final statsResp = await _dio.get(statsUrl);
              if (statsResp.statusCode == 200) {
                final ndviMean =
                    (statsResp.data['mean'] as num?)?.toDouble() ?? 0.0;
                final ndviMax =
                    (statsResp.data['max'] as num?)?.toDouble() ?? ndviMean;
                final ndvi = ((ndviMean + ndviMax) / 2).clamp(0.0, 1.0);

                debugPrint(
                  'ApiService: Real NDVI = $ndvi (mean=$ndviMean, max=$ndviMax)',
                );

                // Clean up polygon
                _cleanupPolygon(polyId, appId);
                return {'ndvi': ndvi, 'source': 'agromonitoring'};
              }
            }
          }
        }
      } catch (e) {
        debugPrint('ApiService: Image search failed: $e');
      }

      // Clean up & fallback
      _cleanupPolygon(polyId, appId);
      debugPrint('ApiService: No satellite data, using fallback');
      return _generateEstimatedNdvi(lat, lng);
    } catch (e) {
      debugPrint('ApiService: NDVI fetch failed: $e. Using fallback.');
      return _generateEstimatedNdvi(lat, lng);
    }
  }

  /// Fire-and-forget polygon cleanup
  void _cleanupPolygon(String polyId, String appId) {
    _dio
        .delete(
          'http://api.agromonitoring.com/agro/1.0/polygons/$polyId',
          queryParameters: {'appid': appId},
        )
        .then((_) => null)
        .catchError((_) => null);
  }

  Future<Map<String, dynamic>> _fetchSoil(double lat, double lng) async {
    try {
      // ISRIC SoilGrids is REST, we can call it directly
      /* 
      final response = await _dio.get(
        'https://rest.isric.org/soilgrids/v2.0/classification/query',
        queryParameters: {'lon': lng, 'lat': lat, 'number_classes': 1},
      );
      */
      await Future.delayed(const Duration(milliseconds: 600));
      return _estimateSoil(lat, lng);
    } catch (e) {
      return _estimateSoil(lat, lng);
    }
  }

  Future<Map<String, dynamic>> _fetchWeather(double lat, double lng) async {
    // OpenWeatherMap Free API does not support CORS.
    // On Web, we must use the fallback to avoid XMLHttpRequest error.
    if (kIsWeb) {
      debugPrint(
        'ApiService: Running on Web, skipping OpenWeather API to avoid CORS. Using fallback.',
      );
      return _estimateWeather(lat, lng);
    }

    debugPrint('ApiService: Fetching weather...');
    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'appid': AppConfig.openWeatherApiKey,
          'units': 'metric',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final temp = (data['main']['temp'] as num).toDouble();
        final humidity = (data['main']['humidity'] as num).toDouble();

        // Simple heuristic for weather index
        double index = 0.5;
        if (temp > 20 && temp < 35 && humidity > 40)
          index = 0.9;
        else if (temp > 10 && temp < 40)
          index = 0.7;
        else
          index = 0.4;

        // Rainfall might be missing or under 'rain' object
        double rain = 0.0;
        if (data['rain'] != null) {
          rain = (data['rain']['1h'] as num?)?.toDouble() ?? 0.0;
        }

        return {
          'weather_index': index,
          'summary': 'Temp: ${temp}°C, Hum: ${humidity}%',
          'temp': temp,
          'rainfall': rain,
          'humidity': humidity,
        };
      }
      debugPrint(
        'ApiService: Weather API returned non-200: ${response.statusCode}',
      );
      return _estimateWeather(lat, lng);
    } catch (e) {
      debugPrint('ApiService: Weather API failed: $e. Using fallback.');
      return _estimateWeather(lat, lng);
    }
  }

  Future<Map<String, dynamic>> _fetchMarket(double lat, double lng) async {
    // Data.gov.in often has rate limits or CORS issues on client.
    // Using regional fallback for stability.
    await Future.delayed(const Duration(milliseconds: 400));
    return _estimateMarket(lat, lng);
  }

  /// Fetch Earth Engine Tile URL from Backend
  Future<String?> getGeeTileUrl(double lat, double lng) async {
    try {
      if (kIsWeb) return null; // GEE tiles on web might need different handling
      final baseUrl = AppConfig.apiBaseUrl;
      final response = await _dio.get(
        '$baseUrl/gee/ndvi-heatmap',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      if (response.statusCode == 200) {
        return response.data['tile_url_format'];
      }
    } catch (e) {
      debugPrint('GEE Fetch Error: $e');
    }
    return null;
  }

  /// Maps new risk categories to DB-allowed values.
  /// DB constraint only allows: 'Low', 'Medium', 'High'.
  String _mapRiskForDb(String category) {
    switch (category) {
      case 'Platinum':
      case 'Gold':
        return 'Low';
      case 'Silver':
        return 'Medium';
      case 'Bronze':
        return 'High';
      default:
        return category; // pass through if already Low/Medium/High
    }
  }

  // ── Fallback Estimators (Ported from Backend) ──────────────────────

  Map<String, dynamic> _generateEstimatedNdvi(double lat, double lng) {
    // Regional base NDVI based on geography
    double baseNdvi;

    // Indo-Gangetic Plain (very fertile)
    if (lat >= 24 && lat <= 30 && lng >= 75 && lng <= 88) {
      baseNdvi = 0.72;
    }
    // Coastal regions (moderate to high)
    else if ((lat >= 8 && lat <= 15 && lng >= 74 && lng <= 80) ||
        (lat >= 15 && lat <= 22 && lng >= 72 && lng <= 78)) {
      baseNdvi = 0.60;
    }
    // Deccan Plateau
    else if (lat >= 15 && lat <= 24 && lng >= 73 && lng <= 82) {
      baseNdvi = 0.55;
    }
    // General agricultural India
    else if (lat >= 8 && lat <= 35 && lng >= 68 && lng <= 97) {
      baseNdvi = 0.50;
    }
    // Arid / desert regions (Rajasthan etc.)
    else if (lat >= 24 && lat <= 30 && lng >= 68 && lng <= 75) {
      baseNdvi = 0.25;
    }
    // Rest of the world
    else {
      baseNdvi = 0.35;
    }

    // Add meaningful variation using both lat & lng
    // Uses sine functions at different frequencies for pseudo-random variation
    final variation1 = sin(lat * 13.7 + lng * 7.3) * 0.12;
    final variation2 = cos(lat * 23.1 - lng * 11.9) * 0.08;
    final variation3 = sin((lat + lng) * 5.3) * 0.05;

    double ndvi = baseNdvi + variation1 + variation2 + variation3;

    return {'ndvi': ndvi.clamp(0.05, 0.95), 'source': 'estimated'};
  }

  Map<String, dynamic> _estimateSoil(double lat, double lng) {
    // Simple regional mapping
    String soil = "Mixed Soil";
    String land = "Agricultural Land";

    if (lat >= 16 && lat <= 24 && lng >= 72 && lng <= 82) {
      soil = "Black Cotton Soil";
      land = "Prime Agricultural Land";
    } else if (lat >= 24 && lat <= 30) {
      soil = "Alluvial Soil";
      land = "Fertile Agricultural Land";
    }

    return {'soil_type': soil, 'land_class': land};
  }

  Map<String, dynamic> _estimateWeather(double lat, double lng) {
    // Generate deterministic pseudo-random values based on location
    final seed = (lat * 1000 + lng * 1000).toInt();
    final random = Random(seed);

    // Temp: 20-35 C
    final temp = 20 + random.nextDouble() * 15;
    // Rainfall: 0-200 mm (seasonal approximation)
    final rainfall = random.nextDouble() * 200;
    // Humidity: 30-90%
    final humidity = 30 + random.nextDouble() * 60;

    String summary;
    if (rainfall > 100)
      summary = 'Heavy Rain, ${temp.toStringAsFixed(1)}°C';
    else if (rainfall > 20)
      summary = 'Light Rain, ${temp.toStringAsFixed(1)}°C';
    else if (temp > 30)
      summary = 'Sunny & Hot, ${temp.toStringAsFixed(1)}°C';
    else
      summary = 'Clear Sky, ${temp.toStringAsFixed(1)}°C';

    return {
      'weather_index': 0.6 + (random.nextDouble() * 0.3),
      'summary': summary,
      'temp': temp,
      'rainfall': rainfall,
      'humidity': humidity,
    };
  }

  Map<String, dynamic> _estimateMarket(double lat, double lng) {
    return {'market_index': 0.70, 'summary': 'Stable market prices'};
  }

  List<Map<String, dynamic>> _generateGridHeatmap(
    double centerLat,
    double centerLng,
    double centerNdvi,
  ) {
    final List<Map<String, dynamic>> points = [];
    const double step = 0.0008; // ~90m spacing for overlap with 120m radius
    final seed = DateTime.now().millisecondsSinceEpoch;

    for (int x = -2; x <= 2; x++) {
      for (int y = -2; y <= 2; y++) {
        final lat = centerLat + (x * step);
        final lng = centerLng + (y * step);

        // Per-point unique noise using sin-based hash
        final pointSeed = (x * 7 + y * 13 + seed) * 0.001;
        final noise = (sin(pointSeed) * 43758.5453).remainder(1.0).abs();

        // Distance penalty: points further from center are slightly lower
        final dist = (x.abs() + y.abs()) * 0.03;

        // Combine: base NDVI ± noise - distance fade
        final variation = (noise - 0.5) * 0.25; // range: -0.125 to +0.125
        final ndvi = (centerNdvi + variation - dist).clamp(0.0, 1.0);

        points.add({'lat': lat, 'lng': lng, 'ndvi': ndvi});
      }
    }
    return points;
  }
}
