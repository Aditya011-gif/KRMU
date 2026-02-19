import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../models/analysis_model.dart';
import '../widgets/score_indicator.dart';
import '../widgets/risk_badge.dart';
import '../widgets/data_card.dart';

class AnalysisResultScreen extends StatelessWidget {
  final AnalysisModel analysis;

  const AnalysisResultScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.surfaceWhite),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(AppConfig.textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analysis Result',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(AppConfig.textDark),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ScoreIndicator(score: analysis.agriScore),
                  const SizedBox(height: 16),
                  RiskBadge(category: analysis.riskCategory),
                  const SizedBox(height: 8),
                  Text(
                    analysis.createdAt != null
                        ? DateFormat(
                            'MMM dd, yyyy – hh:mm a',
                          ).format(analysis.createdAt!)
                        : '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConfig.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Map
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: GoogleMap(
                mapType: MapType.hybrid,
                initialCameraPosition: CameraPosition(
                  target: LatLng(analysis.latitude, analysis.longitude),
                  zoom: 16, // Zoom in closer for "field" view
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('analysis'),
                    position: LatLng(analysis.latitude, analysis.longitude),
                    infoWindow: InfoWindow(
                      title: 'Agri-Score: ${analysis.agriScore.toInt()}',
                      snippet:
                          'NDVI: ${analysis.ndviValue?.toStringAsFixed(2) ?? "N/A"}',
                    ),
                  ),
                },
                polygons: {
                  Polygon(
                    polygonId: const PolygonId('analysis_area'),
                    points: [
                      LatLng(
                        analysis.latitude + 0.003,
                        analysis.longitude - 0.003,
                      ),
                      LatLng(
                        analysis.latitude + 0.003,
                        analysis.longitude + 0.003,
                      ),
                      LatLng(
                        analysis.latitude - 0.003,
                        analysis.longitude + 0.003,
                      ),
                      LatLng(
                        analysis.latitude - 0.003,
                        analysis.longitude - 0.003,
                      ),
                    ],
                    strokeColor: Color(analysis.riskColor).withOpacity(0.8),
                    strokeWidth: 2,
                    fillColor: Color(analysis.riskColor).withOpacity(0.15),
                  ),
                },
                circles: {},
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                liteModeEnabled: false, // Ensure full map for overlay support
              ),
            ),
            const SizedBox(height: 20),

            // AI Predictions Section (moved above Land Intelligence)
            if (analysis.mlPredictions != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.blue.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Predictions',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(AppConfig.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepPurple.shade50, Colors.blue.shade50],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.shade100,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Row 1: Crop Quality + Health Score
                    Row(
                      children: [
                        Expanded(
                          child: _predictionTile(
                            icon: Icons.eco,
                            label: 'Crop Quality',
                            value: analysis.mlPredictions!.cropQuality,
                            color: _qualityColor(
                              analysis.mlPredictions!.cropQuality,
                            ),
                            confidence: analysis
                                .mlPredictions!
                                .confidence['crop_quality'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _predictionTile(
                            icon: Icons.favorite,
                            label: 'Health Score',
                            value:
                                '${analysis.mlPredictions!.cropHealthScore}/100',
                            color: _scoreColor(
                              analysis.mlPredictions!.cropHealthScore,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Risk Level + NDVI Trend
                    Row(
                      children: [
                        Expanded(
                          child: _predictionTile(
                            icon: Icons.shield,
                            label: 'Risk Level',
                            value: analysis.mlPredictions!.riskLevel,
                            color: _riskColor(
                              analysis.mlPredictions!.riskLevel,
                            ),
                            confidence: analysis
                                .mlPredictions!
                                .confidence['risk_level'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _predictionTile(
                            icon: _trendIcon(analysis.mlPredictions!.ndviTrend),
                            label: 'NDVI Trend',
                            value: analysis.mlPredictions!.ndviTrend,
                            color: _trendColor(
                              analysis.mlPredictions!.ndviTrend,
                            ),
                            confidence: analysis
                                .mlPredictions!
                                .confidence['ndvi_trend'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Trend description
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.deepPurple.shade300,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              analysis.mlPredictions!.ndviTrendDescription,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(AppConfig.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Land Intelligence (data cards grid)
            Text(
              'Land Intelligence',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(AppConfig.textDark),
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                DataCard(
                  icon: Icons.satellite_alt,
                  title: 'NDVI Value',
                  value: analysis.ndviValue?.toStringAsFixed(4) ?? 'N/A',
                  subtitle: 'Vegetation health index',
                  iconColor: Colors.green.shade600,
                ),
                DataCard(
                  icon: Icons.terrain,
                  title: 'Soil Type',
                  value: analysis.soilType ?? 'Unknown',
                  subtitle: 'Ground composition',
                  iconColor: Colors.brown.shade600,
                ),
                DataCard(
                  icon: Icons.landscape,
                  title: 'Land Class',
                  value: analysis.landClass ?? 'Unknown',
                  subtitle: 'Land use classification',
                  iconColor: Colors.teal.shade600,
                ),
                DataCard(
                  icon: Icons.cloud,
                  title: 'Weather Index',
                  value:
                      '${((analysis.weatherIndex ?? 0) * 100).toStringAsFixed(0)}%',
                  subtitle: 'Favorable conditions',
                  iconColor: Colors.blue.shade600,
                ),
                DataCard(
                  icon: Icons.trending_up,
                  title: 'Market Index',
                  value:
                      '${((analysis.marketIndex ?? 0) * 100).toStringAsFixed(0)}%',
                  subtitle: 'Price stability',
                  iconColor: Colors.orange.shade600,
                ),
                DataCard(
                  icon: Icons.location_on,
                  title: 'Coordinates',
                  value: '${analysis.latitude.toStringAsFixed(4)}°N',
                  subtitle: '${analysis.longitude.toStringAsFixed(4)}°E',
                  iconColor: Colors.indigo.shade600,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Score Breakdown
            if (analysis.scoreBreakdown != null) ...[
              Text(
                'Score Breakdown',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(AppConfig.textDark),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _breakdownRow(
                      'NDVI (35%)',
                      analysis.scoreBreakdown!.ndviScore,
                      350,
                      Colors.green,
                    ),
                    _breakdownRow(
                      'Soil Quality (25%)',
                      analysis.scoreBreakdown!.soilScore,
                      250,
                      Colors.brown,
                    ),
                    _breakdownRow(
                      'Land Class (15%)',
                      analysis.scoreBreakdown!.landClassScore,
                      150,
                      Colors.teal,
                    ),
                    if (analysis.weatherDetails != null)
                      _weatherDetailsRow(analysis.weatherDetails!)
                    else
                      _breakdownRow(
                        'Weather (15%)',
                        analysis.scoreBreakdown!.weatherScore,
                        150,
                        Colors.blue,
                      ),
                    _breakdownRow(
                      'Market (10%)',
                      analysis.scoreBreakdown!.marketScore,
                      100,
                      Colors.orange,
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Agri-Score',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(AppConfig.textDark),
                          ),
                        ),
                        Text(
                          '${analysis.agriScore.toInt()} / 1000',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(analysis.riskColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, double value, double max, Color color) {
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(AppConfig.textMuted),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} / ${max.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(AppConfig.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    double? confidence,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              if (confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(confidence * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(AppConfig.textMuted),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _qualityColor(String quality) {
    switch (quality) {
      case 'Excellent':
        return Colors.green.shade700;
      case 'Good':
        return Colors.teal.shade600;
      case 'Moderate':
        return Colors.orange.shade700;
      case 'Poor':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green.shade700;
    if (score >= 60) return Colors.teal.shade600;
    if (score >= 40) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  Color _riskColor(String risk) {
    if (risk.contains('Low')) return Colors.green.shade700;
    if (risk.contains('Medium')) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Increase':
        return Icons.trending_up;
      case 'Decrease':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Color _trendColor(String trend) {
    switch (trend) {
      case 'Increase':
        return Colors.green.shade700;
      case 'Decrease':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _weatherDetailsRow(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather Details',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(AppConfig.textMuted),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniWeatherCard(
                  Icons.thermostat,
                  '${(data['temp'] as num).toStringAsFixed(1)}°C',
                  'Temp',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniWeatherCard(
                  Icons.water_drop,
                  '${(data['rainfall'] as num).toStringAsFixed(1)}mm',
                  'Rain',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniWeatherCard(
                  Icons.opacity,
                  '${(data['humidity'] as num).toStringAsFixed(0)}%',
                  'Hum',
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniWeatherCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
