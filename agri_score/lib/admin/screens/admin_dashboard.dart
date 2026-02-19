import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import 'farmer_management.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final stats = await api.getAdminStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stats: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (desktop only)
            if (isWide) _buildSidebar(),

            // Main content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStats,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      title: Text(
                        'Admin Dashboard',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(AppConfig.textDark),
                        ),
                      ),
                      actions: [
                        if (!isWide)
                          IconButton(
                            icon: const Icon(
                              Icons.people,
                              color: Color(AppConfig.primaryGreen),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FarmerManagement(),
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: Color(AppConfig.textMuted),
                          ),
                          onPressed: () =>
                              ref.read(authProvider.notifier).logout(),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(64),
                                child: CircularProgressIndicator(
                                  color: Color(AppConfig.primaryGreen),
                                ),
                              ),
                            ),
                          if (_error != null) _buildErrorCard(),
                          if (_stats != null) ..._buildDashboard(isWide),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF1A1D2E),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.eco_rounded,
                color: Color(AppConfig.primaryGreenLight),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'Agri-Score',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _sidebarItem(Icons.dashboard, 'Dashboard', true),
          _sidebarItem(
            Icons.people,
            'Farmers',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FarmerManagement()),
              );
            },
          ),
          _sidebarItem(Icons.history, 'Audit Logs', false),
          const Spacer(),
          _sidebarItem(
            Icons.logout,
            'Logout',
            false,
            onTap: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? Colors.white : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : Colors.white54,
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
          TextButton(onPressed: _loadStats, child: const Text('Retry')),
        ],
      ),
    );
  }

  List<Widget> _buildDashboard(bool isWide) {
    final totalFarmers = _stats!['total_farmers'] ?? 0;
    final totalAnalyses = _stats!['total_analyses'] ?? 0;
    final avgScore = (_stats!['average_score'] ?? 0).toDouble();
    final riskDist =
        _stats!['risk_distribution'] as Map<String, dynamic>? ?? {};

    return [
      // KPI Cards
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: isWide ? 220 : double.infinity,
            child: _kpiCard(
              'Total Farmers',
              '$totalFarmers',
              Icons.people,
              const Color(AppConfig.primaryGreen),
            ),
          ),
          SizedBox(
            width: isWide ? 220 : double.infinity,
            child: _kpiCard(
              'Total Analyses',
              '$totalAnalyses',
              Icons.analytics,
              Colors.blue,
            ),
          ),
          SizedBox(
            width: isWide ? 220 : double.infinity,
            child: _kpiCard(
              'Avg Score',
              avgScore.toStringAsFixed(0),
              Icons.score,
              Colors.orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Risk Distribution Pie Chart
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Distribution',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: (riskDist['Low'] ?? 0).toDouble(),
                      title: 'Low ${riskDist['Low'] ?? 0}%',
                      color: const Color(AppConfig.primaryGreen),
                      radius: 60,
                      titleStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: (riskDist['Medium'] ?? 0).toDouble(),
                      title: 'Med ${riskDist['Medium'] ?? 0}%',
                      color: const Color(AppConfig.accentAmber),
                      radius: 60,
                      titleStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: (riskDist['High'] ?? 0).toDouble(),
                      title: 'High ${riskDist['High'] ?? 0}%',
                      color: const Color(AppConfig.dangerRed),
                      radius: 60,
                      titleStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // State Distribution Bar Chart
      if ((_stats!['state_distribution'] as Map<String, dynamic>?)
              ?.isNotEmpty ??
          false)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Farmers by State',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(enabled: true),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final states =
                                (_stats!['state_distribution']
                                        as Map<String, dynamic>)
                                    .keys
                                    .toList();
                            if (value.toInt() < states.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  states[value.toInt()].substring(
                                    0,
                                    states[value.toInt()].length > 3
                                        ? 3
                                        : states[value.toInt()].length,
                                  ),
                                  style: GoogleFonts.inter(fontSize: 10),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    barGroups:
                        (_stats!['state_distribution'] as Map<String, dynamic>)
                            .entries
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (e) => BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: (e.value.value as num).toDouble(),
                                    color: const Color(AppConfig.primaryGreen),
                                    width: 20,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),

      // Quick Actions
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FarmerManagement()),
          ),
          icon: const Icon(Icons.people),
          label: Text(
            'Manage Farmers',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(AppConfig.primaryGreen),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      const SizedBox(height: 40),
    ];
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(AppConfig.textDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(AppConfig.textMuted),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
