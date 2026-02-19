import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/land_details_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    Future.microtask(() {
      ref.read(landDetailsProvider.notifier).loadLandDetails();
      ref.read(analysisProvider.notifier).loadHistory();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userProfile = data;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final analysis = ref.watch(analysisProvider);
    final landDetails = ref.watch(landDetailsProvider);

    const primary = Color(AppConfig.primaryGreen);
    const primaryLight = Color(0xFFE8F5E9);
    const textDark = Color(AppConfig.textDark);
    const textMuted = Color(AppConfig.textMuted);
    const bgLight = Color(0xFFF6F8F6);

    final userName =
        _userProfile?['name'] ?? auth.email?.split('@').first ?? 'Farmer';
    final phone = _userProfile?['phone'] ?? '—';
    final state = _userProfile?['state'] ?? '';
    final district = _userProfile?['district'] ?? '';
    final farmSize = _userProfile?['farm_size'];
    final location = [district, state].where((s) => s.isNotEmpty).join(', ');

    // Score data from latest analysis
    final latestAnalysis = analysis.latestResult;
    final agriScore = latestAnalysis?.agriScore ?? 0;
    final ndviValue = latestAnalysis?.ndviValue;
    final soilType = latestAnalysis?.soilType;
    final riskCategory = latestAnalysis?.riskCategory ?? '—';
    final landClass = latestAnalysis?.landClass;

    // Land details data
    final lands = landDetails.registrations;
    final latestLand = lands.isNotEmpty ? lands.first : null;
    final totalLands = lands.length;

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator(color: primary))
            : RefreshIndicator(
                color: primary,
                onRefresh: () async {
                  await _loadProfile();
                  await ref.read(analysisProvider.notifier).loadHistory();
                  await ref
                      .read(landDetailsProvider.notifier)
                      .loadLandDetails();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // ═══ Profile Header ═══
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withOpacity(0.2),
                                  width: 3,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              userName,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: AGS-${auth.userId?.substring(0, 8).toUpperCase() ?? 'UNKNOWN'}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user,
                                    size: 16,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'VERIFIED FARMER',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // ═══ Agri-Trust Score Card ═══
                            _buildSection(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Agri-Trust Score',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (latestAnalysis != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.trending_up,
                                              size: 16,
                                              color: primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '+12 pts',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Score Ring
                                  SizedBox(
                                    width: 140,
                                    height: 140,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 140,
                                          height: 140,
                                          child: CircularProgressIndicator(
                                            value: (agriScore / 1000).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            strokeWidth: 10,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  primary,
                                                ),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              agriScore.toInt().toString(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w800,
                                                color: primary,
                                              ),
                                            ),
                                            Text(
                                              'OF 1000',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: textMuted,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _riskColor(
                                        riskCategory,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$riskCategory Risk',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _riskColor(riskCategory),
                                      ),
                                    ),
                                  ),
                                  if (latestAnalysis?.createdAt != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Last updated: ${DateFormat('MMM dd, yyyy').format(latestAnalysis!.createdAt!)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'View Full Score Analysis',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ═══ Basic Information ═══
                            _buildSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.person_outline,
                                    'Basic Information',
                                  ),
                                  const SizedBox(height: 12),
                                  _infoRow(
                                    Icons.badge_outlined,
                                    'Full Name',
                                    userName,
                                  ),
                                  _infoRow(
                                    Icons.phone_outlined,
                                    'Phone',
                                    phone,
                                  ),
                                  _infoRow(
                                    Icons.fingerprint,
                                    'Identity ID',
                                    'XXXX-XXXX-${auth.userId?.substring(auth.userId!.length - 4) ?? '0000'}',
                                  ),
                                  _infoRow(
                                    Icons.location_on_outlined,
                                    'Location',
                                    location.isNotEmpty ? location : '—',
                                  ),
                                  _infoRow(
                                    Icons.landscape_outlined,
                                    'Landholding',
                                    farmSize != null
                                        ? '${farmSize.toStringAsFixed(1)} Acres'
                                        : '—',
                                  ),
                                  if (latestAnalysis != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Color(0xFFF0F0F0),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.map_outlined,
                                                  size: 18,
                                                  color: primary,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Coordinates',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${latestAnalysis.latitude.toStringAsFixed(4)}° N, ${latestAnalysis.longitude.toStringAsFixed(4)}° E',
                                              style: GoogleFonts.sourceCodePro(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ═══ Agricultural Details ═══
                            _buildSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.agriculture_outlined,
                                    'Agricultural Details',
                                  ),
                                  const SizedBox(height: 14),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 2.1,
                                    children: [
                                      _agriDetailTile(
                                        Icons.grain,
                                        'PRIMARY CROP',
                                        latestLand?.cropType ?? '—',
                                      ),
                                      _agriDetailTile(
                                        Icons.spa_outlined,
                                        'SEASON',
                                        latestLand?.currentSeason ?? '—',
                                      ),
                                      _agriDetailTile(
                                        Icons.filter_hdr_outlined,
                                        'SOIL TYPE',
                                        soilType ?? '—',
                                      ),
                                      _agriDetailTile(
                                        Icons.water_drop_outlined,
                                        'LAND CLASS',
                                        landClass ?? '—',
                                      ),
                                      _agriDetailTile(
                                        Icons.star_outline,
                                        'CROP GRADE',
                                        latestLand?.cropQualityGrade ?? '—',
                                      ),
                                      _agriDetailTile(
                                        Icons.account_balance_wallet_outlined,
                                        'LOAN STATUS',
                                        latestLand?.loanStatus ?? '—',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ═══ Land Intelligence ═══
                            _buildSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.show_chart,
                                    'Land Intelligence',
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statItem(
                                          'Total Lands',
                                          '$totalLands Units',
                                        ),
                                      ),
                                      Expanded(
                                        child: _statItem(
                                          'NDVI Index',
                                          ndviValue?.toStringAsFixed(2) ?? '—',
                                          badge:
                                              ndviValue != null &&
                                                  ndviValue > 0.5
                                              ? 'Optimal'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statItem(
                                          'Soil Class',
                                          soilType ?? '—',
                                        ),
                                      ),
                                      Expanded(
                                        child: _statItem(
                                          'Last Analysis',
                                          latestAnalysis?.createdAt != null
                                              ? DateFormat(
                                                  'MMM dd, yyyy',
                                                ).format(
                                                  latestAnalysis!.createdAt!,
                                                )
                                              : '—',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Satellite view placeholder
                                  Container(
                                    width: double.infinity,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'Satellite View',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ═══ Verification Status ═══
                            _buildSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.verified_outlined,
                                    'Verification Status',
                                  ),
                                  const SizedBox(height: 12),
                                  _verificationRow(
                                    Icons.article_outlined,
                                    'Land Ownership',
                                    true,
                                  ),
                                  _verificationRow(
                                    Icons.badge_outlined,
                                    'Identity Verification',
                                    true,
                                  ),
                                  _verificationRow(
                                    Icons.history_edu_outlined,
                                    'Loan History',
                                    false,
                                  ),
                                  _verificationRow(
                                    Icons.check_circle_outline,
                                    'User Consent',
                                    true,
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primary,
                                        backgroundColor: primaryLight,
                                        side: BorderSide(
                                          color: primary.withOpacity(0.2),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Manage Land & Identity Documents',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ═══ App Settings ═══
                            _buildSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.settings_outlined,
                                    'App Settings',
                                  ),
                                  const SizedBox(height: 4),
                                  _settingsRow(
                                    Icons.language,
                                    'Language Selection',
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'English',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _settingsRow(
                                    Icons.notifications_outlined,
                                    'Push Notifications',
                                    trailing: Switch(
                                      value: true,
                                      onChanged: (_) {},
                                      activeColor: primary,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  _settingsRow(
                                    Icons.lock_outline,
                                    'Privacy Settings',
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: textMuted,
                                    ),
                                  ),
                                  _settingsRow(
                                    Icons.password,
                                    'Change App PIN',
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: textMuted,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  // Logout
                                  InkWell(
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Logout'),
                                          content: const Text(
                                            'Are you sure you want to logout?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Logout',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && mounted) {
                                        await ref
                                            .read(authProvider.notifier)
                                            .logout();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.logout,
                                            size: 22,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Logout',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 80,
                            ), // Bottom padding for nav
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Helper Widgets ───

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(AppConfig.primaryGreen), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(AppConfig.textMuted),
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _agriDetailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(AppConfig.primaryGreen)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConfig.textMuted),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {String? badge}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(AppConfig.textMuted),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(AppConfig.primaryGreen).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConfig.primaryGreen),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _verificationRow(IconData icon, String label, bool isVerified) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isVerified
                    ? const Color(AppConfig.primaryGreen)
                    : Colors.orange,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isVerified
                  ? const Color(AppConfig.primaryGreen).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isVerified ? 'Verified' : 'Pending',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isVerified
                    ? const Color(AppConfig.primaryGreen)
                    : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(IconData icon, String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Color _riskColor(String category) {
    switch (category) {
      case 'Low':
        return const Color(AppConfig.primaryGreen);
      case 'Medium':
        return const Color(AppConfig.accentAmber);
      case 'High':
        return const Color(AppConfig.dangerRed);
      default:
        return Colors.grey;
    }
  }
}
