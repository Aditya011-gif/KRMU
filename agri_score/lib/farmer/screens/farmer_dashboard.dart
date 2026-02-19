import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/fraud_risk_provider.dart';
import '../widgets/score_indicator.dart';
import '../widgets/risk_badge.dart';
import '../widgets/dashboard_widgets.dart';
import 'land_analysis_screen.dart';
import 'analysis_result_screen.dart';
import 'fraud_risk_detail_screen.dart';

class FarmerDashboard extends ConsumerStatefulWidget {
  const FarmerDashboard({super.key});

  @override
  ConsumerState<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends ConsumerState<FarmerDashboard> {
  final _coordsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analysisProvider.notifier).loadHistory());
  }

  @override
  void dispose() {
    _coordsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final analysis = ref.watch(analysisProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6), // Background Light from HTML
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(AppConfig.primaryGreen),
          onRefresh: () => ref.read(analysisProvider.notifier).loadHistory(),
          child: CustomScrollView(
            slivers: [
              // 1. Custom Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  AppConfig.primaryGreen,
                                ).withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ), // Placeholder avatar
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(AppConfig.textMuted),
                                ),
                              ),
                              Text(
                                'Hello, ${auth.email?.split('@').first ?? 'Farmer'}',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(AppConfig.textDark),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {}, // Notifications stub
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.grey,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              height: 8,
                              width: 8,
                              decoration: const BoxDecoration(
                                color: Color(AppConfig.dangerRed),
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Hero Score Card
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04), // 0.05 in HTML
                          blurRadius: 20, // 20px
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'AGRI-SCORE™',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(AppConfig.textMuted),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: analysis.latestResult != null
                              ? ScoreIndicator(
                                  score: analysis.latestResult!.agriScore,
                                  size: 190,
                                )
                              : Column(
                                  children: [
                                    const Icon(
                                      Icons.eco_outlined,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No Data',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (analysis.latestResult != null) ...[
                          const SizedBox(height: 10),
                          RiskBadge(
                            category: analysis.latestResult!.riskCategory,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Updated today • ${DateFormat('hh:mm a').format(DateTime.now())}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(AppConfig.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                          height: 1,
                          color: Color(0xFFEEEEEE),
                        ), // gray-100
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Credit Capacity',
                              style: GoogleFonts.inter(
                                color: const Color(AppConfig.textMuted),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              analysis.latestResult != null
                                  ? '₹${NumberFormat('#,##,###', 'en_IN').format(_calculateCreditCapacity(analysis.latestResult!.agriScore))}'
                                  : '—',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(AppConfig.textDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Land Metrics Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Land Metrics',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(AppConfig.textDark),
                        ),
                      ),
                      TextButton(
                        onPressed: () {}, // View All stub
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(AppConfig.primaryGreen),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Metrics Horizontal List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140, // Height for MetricCards
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (analysis.latestResult != null) ...[
                        MetricCard(
                          label: 'NDVI Index',
                          value:
                              analysis.latestResult!.ndviValue?.toStringAsFixed(
                                2,
                              ) ??
                              'N/A',
                          icon: Icons.grass, // yard replacement
                          color: const Color(AppConfig.primaryGreen),
                          bgColor: const Color(0xFFE8F5E9), // green-50
                        ),
                        const SizedBox(width: 12),
                        MetricCard(
                          label: 'Soil Type',
                          value: analysis.latestResult!.soilType ?? 'Unknown',
                          icon: Icons.layers,
                          color: const Color(
                            AppConfig.accentAmber,
                          ), // amber-700
                          bgColor: const Color(0xFFFFF8E1), // amber-50
                        ),
                        const SizedBox(width: 12),
                        MetricCard(
                          label: 'Land Class',
                          value: analysis.latestResult!.landClass ?? 'Unknown',
                          icon: Icons.agriculture,
                          color: Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                        ),
                        const SizedBox(width: 12),
                        MetricCard(
                          label: 'Weather Risk',
                          value: 'Low', // Placeholder/Derived
                          icon: Icons.wb_sunny,
                          color: Colors.purple.shade700,
                          bgColor: Colors.purple.shade50,
                        ),
                      ] else ...[
                        const Center(
                          child: Text(
                            "    No metrics available yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.symmetric(vertical: 12)),

              // 5. Analyze New Land Card
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: AnalyzeLandCard(
                    controller: _coordsCtrl,
                    onAnalyzeTap: () {
                      // Navigate to analysis result or trigger analysis
                      // For now, redirect to existing LandAnalysisScreen for manual flow
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LandAnalysisScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.symmetric(vertical: 12)),

              // 5.5 Land Overview Map — Mock Data Demo
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Land Overview',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(AppConfig.textDark),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        GoogleMap(
                          mapType: MapType.hybrid,
                          initialCameraPosition: const CameraPosition(
                            // Center between all 4 zones (Haryana region)
                            target: LatLng(29.45, 76.98),
                            zoom: 8.5,
                          ),
                          markers: _buildMockMarkers(),
                          circles: _buildMockHeatmapCircles(),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: true,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          zoomGesturesEnabled: true,
                          liteModeEnabled: false,
                        ),
                        // Color Legend overlay
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'NDVI Heat Index',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _legendRow(Colors.green, 'Farmland (0.6–0.9)'),
                                _legendRow(Colors.yellow, 'Moderate (0.4–0.6)'),
                                _legendRow(Colors.orange, 'Low Veg (0.2–0.4)'),
                                _legendRow(Colors.red, 'Industrial (< 0.2)'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.symmetric(vertical: 12)),

              // ── Fraud Risk Monitoring Card ──
              _buildFraudRiskCard(ref),

              const SliverPadding(padding: EdgeInsets.symmetric(vertical: 8)),

              // 6. Recent Analysis Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent Analysis',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(AppConfig.textDark),
                    ),
                  ),
                ),
              ),

              // 7. Recent Analysis Card (Chart + List)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  100,
                ), // Bottom padding for nav/action buttons
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Chart
                        const ScoreTrendChart(),
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 16),

                        // List
                        if (analysis.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (analysis.history.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "No history available",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ...analysis.history
                              .take(3)
                              .map(
                                (item) => RecentAnalysisCard(
                                  analysis: item,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AnalysisResultScreen(analysis: item),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fraud Risk Monitoring Card ──────────────────────────
  Widget _buildFraudRiskCard(WidgetRef ref) {
    final result = ref.watch(fraudRiskProvider);
    final catColor = Color(result.fraudRiskCategory.color);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: catColor.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: catColor.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: catColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fraud Risk Monitoring',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(AppConfig.textDark),
                          ),
                        ),
                        Text(
                          'Supervisory integrity layer',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(AppConfig.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.manualReviewRequired)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(
                          AppConfig.accentAmber,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(AppConfig.accentAmber),
                        size: 18,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Score row
              Row(
                children: [
                  // Circular score
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: CircularProgressIndicator(
                            value: result.fraudRiskScore / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(catColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${result.fraudRiskScore}',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Info column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${result.fraudRiskCategory.label} Risk',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.isClean
                              ? 'All integrity checks passed.'
                              : '${result.triggeredRules.length} rule(s) triggered',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(AppConfig.textMuted),
                          ),
                        ),
                        if (result.manualReviewRequired) ...[
                          const SizedBox(height: 4),
                          Text(
                            '⚠ Manual review required',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConfig.accentAmber),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // View Details button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FraudRiskDetailScreen(),
                    ),
                  ),
                  icon: Icon(
                    Icons.visibility_rounded,
                    size: 18,
                    color: catColor,
                  ),
                  label: Text(
                    'View Details',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: catColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: catColor.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mock Data: 4 zones in Haryana ───
  // Coordinates the user can verify on Google Maps:
  //
  // 🌾 FARMLAND (high NDVI 0.65–0.85):
  //   1. Karnal, Haryana    → 29.6857°N, 76.9905°E
  //   2. Kurukshetra         → 29.9695°N, 76.8783°E
  //
  // 🏭 INDUSTRIAL (low NDVI 0.10–0.30):
  //   3. Panipat Refinery    → 29.3909°N, 76.9635°E
  //   4. Kundli/Sonipat      → 28.9931°N, 77.0151°E

  static const _mockZones = [
    // Farmland zones
    {
      'name': '🌾 Karnal Farmland',
      'lat': 29.6857,
      'lng': 76.9905,
      'ndvi': 0.78,
      'type': 'farm',
    },
    {
      'name': '🌾 Kurukshetra Fields',
      'lat': 29.9695,
      'lng': 76.8783,
      'ndvi': 0.72,
      'type': 'farm',
    },
    // Industrial zones
    {
      'name': '🏭 Panipat Industrial',
      'lat': 29.3909,
      'lng': 76.9635,
      'ndvi': 0.18,
      'type': 'industrial',
    },
    {
      'name': '🏭 Kundli/Sonipat Mfg',
      'lat': 28.9931,
      'lng': 77.0151,
      'ndvi': 0.22,
      'type': 'industrial',
    },
  ];

  Set<Marker> _buildMockMarkers() {
    return _mockZones.map((zone) {
      final lat = (zone['lat'] as num).toDouble();
      final lng = (zone['lng'] as num).toDouble();
      return Marker(
        markerId: MarkerId('mock_${zone['name']}'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: zone['name'] as String,
          snippet: 'NDVI: ${(zone['ndvi'] as num).toStringAsFixed(2)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          zone['type'] == 'farm'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueRed,
        ),
      );
    }).toSet();
  }

  /// Converts NDVI (0.0–1.0) to a smooth gradient color using HSL.
  /// Red (0.0) → Orange → Yellow → Green (1.0)
  Color _ndviToColor(double ndvi) {
    // Hue: 0 (red) → 30 (orange) → 60 (yellow) → 120 (green)
    final hue = (ndvi.clamp(0.0, 1.0) * 120.0);
    // Saturation: vivid across the range
    const saturation = 0.85;
    // Lightness: slightly brighter in the middle for visibility
    final lightness = 0.38 + (ndvi * 0.12);
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Set<Circle> _buildMockHeatmapCircles() {
    final Set<Circle> circles = {};
    const double step = 0.006; // ~600m grid step (denser coverage)
    int index = 0;

    for (final zone in _mockZones) {
      final centerLat = (zone['lat'] as num).toDouble();
      final centerLng = (zone['lng'] as num).toDouble();
      final baseNdvi = (zone['ndvi'] as num).toDouble();
      final isFarm = zone['type'] == 'farm';

      for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
          final lat = centerLat + (x * step);
          final lng = centerLng + (y * step);

          // Per-point unique noise for natural variation
          final seed = (x * 7 + y * 13 + index * 31) * 0.1;
          final noise = ((seed * 43758.5453) % 1.0).abs();
          final dist = (x.abs() + y.abs()) * 0.015;
          final variation = (noise - 0.5) * 0.12;
          final ndvi = (baseNdvi + variation - dist).clamp(0.0, 1.0);

          final baseColor = _ndviToColor(ndvi);
          final baseRadius = isFarm ? 750.0 : 600.0;

          // Layer 1: Large faint outer glow
          circles.add(
            Circle(
              circleId: CircleId('glow_${index}_${x}_$y'),
              center: LatLng(lat, lng),
              radius: baseRadius * 1.6,
              fillColor: baseColor.withOpacity(0.12),
              strokeWidth: 0,
            ),
          );

          // Layer 2: Medium semi-transparent body
          circles.add(
            Circle(
              circleId: CircleId('body_${index}_${x}_$y'),
              center: LatLng(lat, lng),
              radius: baseRadius,
              fillColor: baseColor.withOpacity(0.35),
              strokeColor: baseColor.withOpacity(0.15),
              strokeWidth: 1,
            ),
          );

          // Layer 3: Small vivid center dot
          circles.add(
            Circle(
              circleId: CircleId('core_${index}_${x}_$y'),
              center: LatLng(lat, lng),
              radius: baseRadius * 0.45,
              fillColor: baseColor.withOpacity(0.6),
              strokeColor: baseColor.withOpacity(0.3),
              strokeWidth: 1,
            ),
          );
        }
      }
      index++;
    }
    return circles;
  }

  /// Calculates estimated credit capacity in ₹ based on agri score (0–1000).
  /// Logic: Higher score → higher creditworthiness.
  ///   Score 0–300   → ₹50,000 – ₹2,00,000   (Low / High Risk)
  ///   Score 300–600  → ₹2,00,000 – ₹5,00,000 (Moderate)
  ///   Score 600–800  → ₹5,00,000 – ₹8,00,000 (Good)
  ///   Score 800–1000 → ₹8,00,000 – ₹12,50,000 (Excellent)
  int _calculateCreditCapacity(double score) {
    final s = score.clamp(0, 1000);
    // Non-linear scaling: better scores get proportionally more credit
    final ratio = s / 1000.0;
    final capacity = 50000 + (ratio * ratio * 1200000); // ₹50K to ~₹12.5L
    // Round to nearest ₹10,000
    return ((capacity / 10000).round() * 10000);
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
