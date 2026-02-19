import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';

import '../../providers/auth_provider.dart';

import '../../farmer/widgets/score_indicator.dart';
import '../../farmer/widgets/risk_badge.dart';

class FarmerDetailScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const FarmerDetailScreen({super.key, required this.farmerId});

  @override
  ConsumerState<FarmerDetailScreen> createState() => _FarmerDetailScreenState();
}

class _FarmerDetailScreenState extends ConsumerState<FarmerDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final detail = await api.getAdminFarmerDetail(widget.farmerId);
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load farmer details';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
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
          'Farmer Detail',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(AppConfig.textDark),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(AppConfig.primaryGreen),
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  TextButton(
                    onPressed: _loadDetail,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile card
                  _buildProfileCard(),
                  const SizedBox(height: 20),

                  // Score overview
                  if (_detail!['average_score'] != null) _buildScoreOverview(),
                  const SizedBox(height: 20),

                  // Map preview (latest analysis)
                  if ((_detail!['analyses'] as List?)?.isNotEmpty ?? false)
                    _buildMapPreview(),
                  const SizedBox(height: 20),

                  // Analysis history
                  Text(
                    'Analysis History',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(_detail!['analyses'] as List? ?? []).map(
                    (a) => _analysisCard(a as Map<String, dynamic>),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final user = _detail!['user'] as Map<String, dynamic>? ?? {};
    return Container(
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
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(
              AppConfig.primaryGreen,
            ).withOpacity(0.1),
            child: Text(
              (user['name'] as String? ?? 'U')[0].toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(AppConfig.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user['name'] ?? 'Unknown',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user['email'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(AppConfig.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _infoChip(Icons.phone, user['phone'] ?? '—'),
              _infoChip(Icons.map, user['state'] ?? '—'),
              _infoChip(Icons.location_city, user['district'] ?? '—'),
              _infoChip(Icons.landscape, '${user['farm_size'] ?? '—'} acres'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(AppConfig.textMuted)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(AppConfig.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          ScoreIndicator(
            score: (_detail!['average_score'] as num?)?.toDouble() ?? 0,
            size: 140,
          ),
          const SizedBox(height: 12),
          if (_detail!['latest_risk'] != null)
            RiskBadge(category: _detail!['latest_risk']),
          const SizedBox(height: 8),
          Text(
            '${_detail!['total_analyses'] ?? 0} analyses performed',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(AppConfig.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    final latest = (_detail!['analyses'] as List).first as Map<String, dynamic>;
    final lat = (latest['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (latest['longitude'] as num?)?.toDouble() ?? 0;

    return Container(
      height: 180,
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
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 12,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('latest'),
            position: LatLng(lat, lng),
          ),
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        liteModeEnabled: true,
      ),
    );
  }

  Widget _analysisCard(Map<String, dynamic> a) {
    final score = (a['agri_score'] as num?)?.toDouble() ?? 0;
    final risk = a['risk_category'] as String? ?? 'Unknown';
    final date = a['created_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(a['created_at']))
        : '';

    Color riskColor;
    switch (risk) {
      case 'Low':
        riskColor = const Color(AppConfig.primaryGreen);
        break;
      case 'Medium':
        riskColor = const Color(AppConfig.accentAmber);
        break;
      default:
        riskColor = const Color(AppConfig.dangerRed);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                score.toInt().toString(),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: riskColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(a['latitude'] as num?)?.toStringAsFixed(4) ?? '0'}, ${(a['longitude'] as num?)?.toStringAsFixed(4) ?? '0'}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConfig.textDark),
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(AppConfig.textMuted),
                  ),
                ),
              ],
            ),
          ),
          RiskBadge(category: risk, fontSize: 11),
        ],
      ),
    );
  }
}
