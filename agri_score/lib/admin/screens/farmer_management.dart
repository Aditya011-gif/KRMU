import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_config.dart';

import '../../providers/auth_provider.dart';
import 'farmer_detail_screen.dart';

class FarmerManagement extends ConsumerStatefulWidget {
  const FarmerManagement({super.key});

  @override
  ConsumerState<FarmerManagement> createState() => _FarmerManagementState();
}

class _FarmerManagementState extends ConsumerState<FarmerManagement> {
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedState;
  String? _selectedRisk;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFarmers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final farmers = await api.getAdminFarmers(
        state: _selectedState,
        riskCategory: _selectedRisk,
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      );
      setState(() {
        _farmers = farmers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load farmers';
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
          'Farmer Management',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(AppConfig.textDark),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.download,
              color: Color(AppConfig.primaryGreen),
            ),
            tooltip: 'Export CSV',
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadFarmers(),
                  decoration: InputDecoration(
                    hintText: 'Search farmers...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _loadFarmers();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _filterDropdown(
                        value: _selectedRisk,
                        hint: 'Risk',
                        items: ['Low', 'Medium', 'High'],
                        onChanged: (v) {
                          setState(() => _selectedRisk = v);
                          _loadFarmers();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _filterDropdown(
                        value: _selectedState,
                        hint: 'State',
                        items: [
                          'Punjab',
                          'Haryana',
                          'Uttar Pradesh',
                          'Maharashtra',
                          'Karnataka',
                          'Tamil Nadu',
                          'Gujarat',
                          'Madhya Pradesh',
                          'Rajasthan',
                        ],
                        onChanged: (v) {
                          setState(() => _selectedState = v);
                          _loadFarmers();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.clear_all,
                        color: Color(AppConfig.textMuted),
                      ),
                      tooltip: 'Clear filters',
                      onPressed: () {
                        setState(() {
                          _selectedState = null;
                          _selectedRisk = null;
                          _searchCtrl.clear();
                        });
                        _loadFarmers();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
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
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        TextButton(
                          onPressed: _loadFarmers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _farmers.isEmpty
                ? Center(
                    child: Text(
                      'No farmers found',
                      style: GoogleFonts.inter(
                        color: const Color(AppConfig.textMuted),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFarmers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _farmers.length,
                      itemBuilder: (ctx, i) => _farmerCard(_farmers[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13)),
          isExpanded: true,
          items: items
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: GoogleFonts.inter(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _farmerCard(Map<String, dynamic> farmer) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FarmerDetailScreen(farmerId: farmer['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(
                AppConfig.primaryGreen,
              ).withOpacity(0.1),
              child: Text(
                (farmer['name'] as String? ?? 'U')[0].toUpperCase(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: const Color(AppConfig.primaryGreen),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmer['name'] ?? 'Unknown',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConfig.textDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${farmer['state'] ?? '—'} · ${farmer['district'] ?? '—'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConfig.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            if (farmer['latest_score'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _riskColor(farmer['latest_risk']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(farmer['latest_score'] as num).toInt()}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _riskColor(farmer['latest_risk']),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(AppConfig.textMuted)),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String? risk) {
    switch (risk) {
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

  Future<void> _exportCSV() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading CSV export...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // In production, this would trigger file download
  }
}
