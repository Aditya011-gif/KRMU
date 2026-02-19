import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../models/analysis_model.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(AppConfig.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(AppConfig.textDark),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class AnalyzeLandCard extends StatefulWidget {
  final VoidCallback onAnalyzeTap;
  final TextEditingController controller;

  const AnalyzeLandCard({
    super.key,
    required this.onAnalyzeTap,
    required this.controller,
  });

  @override
  State<AnalyzeLandCard> createState() => _AnalyzeLandCardState();
}

class _AnalyzeLandCardState extends State<AnalyzeLandCard> {
  String _mapUrl = '';

  @override
  void initState() {
    super.initState();
    _mapUrl = _buildStaticMapUrl(28.6, 77.0);
    widget.controller.addListener(_onCoordsChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCoordsChanged);
    super.dispose();
  }

  void _onCoordsChanged() {
    final text = widget.controller.text.trim();
    final parts = text.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        setState(() {
          _mapUrl = _buildStaticMapUrl(lat, lng);
        });
      }
    }
  }

  String _buildStaticMapUrl(double lat, double lng) {
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=13'
        '&size=600x300'
        '&maptype=hybrid'
        '&markers=color:green%7C$lat,$lng'
        '&key=${AppConfig.googleMapsApiKey}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze New Land',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(AppConfig.textDark),
            ),
          ),
          const SizedBox(height: 16),
          // Input
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                hintText: 'Enter coordinates (lat, lng)',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.pin_drop_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.my_location,
                    color: Color(AppConfig.primaryGreen),
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Implement current location
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Map Preview — Google Maps Static API
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 140,
              width: double.infinity,
              color: const Color(0xFFE8E8E8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _mapUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                          color: const Color(AppConfig.primaryGreen),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Map preview unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Subtle gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.satellite_alt,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Satellite View',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: widget.onAnalyzeTap,
              icon: const Icon(Icons.analytics_outlined, size: 20),
              label: Text(
                'Analyze Land',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConfig.primaryGreen),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreTrendChart extends StatelessWidget {
  const ScoreTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Score Trend (6mo)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(AppConfig.textMuted),
              ),
            ),
            const Text(
              '+12%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.primaryGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.4, false),
              _bar(0.55, false),
              _bar(0.45, false),
              _bar(0.6, false),
              _bar(0.75, true), // Getting better
              _bar(0.65, true),
              _bar(0.85, true, isCurrent: true), // Current
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(double heightFactor, bool isGood, {bool isCurrent = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(AppConfig.primaryGreen)
                  : isGood
                  ? const Color(AppConfig.primaryGreen).withOpacity(0.3)
                  : const Color(AppConfig.primaryGreen).withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecentAnalysisCard extends StatelessWidget {
  final AnalysisModel analysis;
  final VoidCallback onTap;

  const RecentAnalysisCard({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color riskColor;
    if (analysis.riskCategory == 'Low') {
      riskColor = const Color(AppConfig.primaryGreen);
    } else if (analysis.riskCategory == 'Medium') {
      riskColor = const Color(AppConfig.accentAmber);
    } else {
      riskColor = const Color(AppConfig.dangerRed);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ), // Minimal padding as per design, separated by border usually, but card here
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.landscape, color: Colors.grey),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Field Analysis ${analysis.id.length >= 4 ? analysis.id.substring(0, 4) : analysis.id}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(AppConfig.textDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    analysis.createdAt != null
                        ? DateFormat('MMM dd, yyyy').format(analysis.createdAt!)
                        : '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConfig.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  analysis.agriScore.toInt().toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConfig.textDark),
                  ),
                ),
                Text(
                  analysis.riskCategory,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
