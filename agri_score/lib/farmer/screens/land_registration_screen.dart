import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_config.dart';
import '../../providers/land_details_provider.dart';

class LandRegistrationScreen extends ConsumerStatefulWidget {
  const LandRegistrationScreen({super.key});

  @override
  ConsumerState<LandRegistrationScreen> createState() =>
      _LandRegistrationScreenState();
}

class _LandRegistrationScreenState
    extends ConsumerState<LandRegistrationScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _loanAmountCtrl = TextEditingController();
  final _loanProviderCtrl = TextEditingController();

  String _areaUnit = 'Acres';
  String? _cropType;
  String? _cropQualityGrade;
  String? _currentSeason;
  String? _loanStatus;
  bool _isLocating = false;

  List<PlatformFile> _loanDocs = [];
  List<PlatformFile> _ownershipDocs = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _areaCtrl.dispose();
    _loanAmountCtrl.dispose();
    _loanProviderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(bool isLoanDoc) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true, // Important for Web
      );

      if (result != null) {
        setState(() {
          if (isLoanDoc) {
            _loanDocs.addAll(result.files);
          } else {
            _ownershipDocs.addAll(result.files);
          }
        });
      }
    } catch (e) {
      _showSnackbar('Error picking file: $e', isError: true);
    }
  }

  void _removeDocument(bool isLoanDoc, int index) {
    setState(() {
      if (isLoanDoc) {
        _loanDocs.removeAt(index);
      } else {
        _ownershipDocs.removeAt(index);
      }
    });
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Location services are disabled', isError: true);
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Location permission denied', isError: true);
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar('Location permission permanently denied', isError: true);
        setState(() => _isLocating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        _isLocating = false;
      });
    } catch (e) {
      _showSnackbar('Could not get location: $e', isError: true);
      setState(() => _isLocating = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? const Color(AppConfig.dangerRed)
            : const Color(AppConfig.primaryGreen),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);

    if (lat == null || lng == null) {
      _showSnackbar('Please enter valid coordinates', isError: true);
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showSnackbar('Coordinates out of range', isError: true);
      return;
    }

    final landArea = double.tryParse(_areaCtrl.text);
    final loanAmount = double.tryParse(_loanAmountCtrl.text);

    setState(() => _isUploading = true);

    // Upload documents
    List<String> loanDocUrls = [];
    List<String> ownershipDocUrls = [];

    try {
      final notifier = ref.read(landDetailsProvider.notifier);

      for (var file in _loanDocs) {
        final url = await notifier.uploadFile(file, 'land_documents');
        if (url != null) loanDocUrls.add(url);
      }

      for (var file in _ownershipDocs) {
        final url = await notifier.uploadFile(file, 'land_documents');
        if (url != null) ownershipDocUrls.add(url);
      }
    } catch (e) {
      _showSnackbar('Error uploading documents: $e', isError: true);
      setState(() => _isUploading = false);
      return;
    }

    setState(() => _isUploading = false);

    final success = await ref
        .read(landDetailsProvider.notifier)
        .submitLandDetails(
          latitude: lat,
          longitude: lng,
          landArea: landArea,
          areaUnit: _areaUnit,
          cropType: _cropType,
          cropQualityGrade: _cropQualityGrade,
          currentSeason: _currentSeason,
          pastLoanAmount: loanAmount,
          loanProvider: _loanProviderCtrl.text.isNotEmpty
              ? _loanProviderCtrl.text
              : null,
          loanStatus: _loanStatus,
          loanDocuments: loanDocUrls.isNotEmpty ? loanDocUrls : null,
          ownershipDocuments: ownershipDocUrls.isNotEmpty
              ? ownershipDocUrls
              : null,
        );

    if (success && mounted) {
      _showSnackbar('Land details registered successfully!');
      _clearForm();
    } else if (mounted) {
      final state = ref.read(landDetailsProvider);
      if (state.error != null) {
        _showSnackbar(state.error!, isError: true);
      }
    }
  }

  void _clearForm() {
    _latCtrl.clear();
    _lngCtrl.clear();
    _areaCtrl.clear();
    _loanAmountCtrl.clear();
    _loanProviderCtrl.clear();
    setState(() {
      _cropType = null;
      _cropQualityGrade = null;
      _currentSeason = null;
      _loanStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landDetailsProvider);
    const primary = Color(AppConfig.primaryGreen);
    const primaryLight = Color(0xFFE8F5E9);
    const textDark = Color(AppConfig.textDark);
    const textMuted = Color(AppConfig.textMuted);
    const bgLight = Color(0xFFF6F8F6);

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Register Your Land Details',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    Text(
                      'Calculate your Agri-Trust Score',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload land information and documents to verify your farm\'s health and financial standing.',
                      style: GoogleFonts.inter(fontSize: 14, color: textMuted),
                    ),
                    const SizedBox(height: 24),

                    // ═══ Card 1: Land Information ═══
                    _buildCard(
                      icon: Icons.map_outlined,
                      title: 'Land Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Lat / Lng
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Latitude',
                                  controller: _latCtrl,
                                  hint: '0.0000',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  label: 'Longitude',
                                  controller: _lngCtrl,
                                  hint: '0.0000',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Detect Location Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isLocating ? null : _detectLocation,
                              icon: _isLocating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primary,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                              label: Text(
                                _isLocating
                                    ? 'Detecting...'
                                    : 'Detect Location Automatically',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                backgroundColor: primaryLight,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Land Area + Unit
                          _buildLabel('Land Area'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _areaCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 15),
                                  decoration: _inputDecoration(
                                    hint: 'Enter area',
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: bgLight,
                                  border: Border.all(
                                    color: primary.withOpacity(0.2),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _areaUnit,
                                    items: ['Acres', 'Hectares']
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(
                                              u,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _areaUnit = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Crop Type
                          _buildDropdown(
                            label: 'Crop Type',
                            value: _cropType,
                            hint: 'Select Crop',
                            items: ['Wheat', 'Rice', 'Maize', 'Cotton'],
                            onChanged: (v) => setState(() => _cropType = v),
                          ),
                          const SizedBox(height: 16),

                          // Crop Quality Grade
                          _buildDropdown(
                            label: 'Crop Quality Grade',
                            value: _cropQualityGrade,
                            hint: 'Select Grade',
                            items: ['Grade A', 'Grade B', 'Grade C', 'Premium'],
                            onChanged: (v) =>
                                setState(() => _cropQualityGrade = v),
                          ),
                          const SizedBox(height: 16),

                          // Current Season Radio
                          _buildLabel('Current Season'),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Kharif', 'Rabi', 'Zaid']
                                .map(
                                  (s) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: _buildSeasonChip(s),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ═══ Card 2: Financial Information ═══
                    _buildCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Financial Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Past Loan Amount
                          _buildLabel('Past Loan Amount'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _loanAmountCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 15),
                            decoration: _inputDecoration(
                              hint: '0.00',
                              prefix: '₹ ',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Loan Provider
                          _buildTextField(
                            label: 'Loan Provider',
                            controller: _loanProviderCtrl,
                            hint: 'e.g. Agri Bank',
                          ),
                          const SizedBox(height: 16),

                          // Loan Status
                          _buildLabel('Loan Status'),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Active', 'Closed', 'Defaulted']
                                .map(
                                  (s) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: _buildStatusChip(s),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),

                          // Upload Loan Statements (UI only)
                          _buildLabel('Upload Loan Statements'),
                          const SizedBox(height: 8),
                          _buildUploadArea(
                            icon: Icons.cloud_upload_outlined,
                            title: 'Drop files here or click to browse',
                            subtitle: 'PDF, JPG, PNG (Max 10MB)',
                            isLoanDoc: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ═══ Card 3: Land Ownership Documents ═══
                    _buildCard(
                      icon: Icons.description_outlined,
                      title: 'Land Ownership Documents',
                      child: _buildUploadArea(
                        icon: Icons.upload_file_outlined,
                        title: 'Upload Land Documents',
                        subtitle: 'Patta, RTC, Ownership Papers',
                        isLoanDoc: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Fixed Bottom Action Bar ──
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          border: const Border(
            top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (state.isSubmitting || _isUploading)
                      ? null
                      : _handleSubmit,
                  icon: (state.isSubmitting || _isUploading)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.analytics_outlined, size: 22),
                  label: Text(
                    _isUploading
                        ? 'Uploading Documents...'
                        : state.isSubmitting
                        ? 'Submitting...'
                        : 'Submit and Analyze Land',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: primary.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Your documents are securely encrypted and protected',
                    style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared UI Builders ───

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(AppConfig.primaryGreen).withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(AppConfig.primaryGreen),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(AppConfig.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(AppConfig.textDark),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? prefix,
    BorderRadius? borderRadius,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(AppConfig.textMuted),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(AppConfig.primaryGreen).withOpacity(0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(AppConfig.primaryGreen).withOpacity(0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(AppConfig.primaryGreen),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(AppConfig.primaryGreen).withOpacity(0.2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(AppConfig.textMuted),
                ),
              ),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: const Color(AppConfig.primaryGreen).withOpacity(0.6),
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: GoogleFonts.inter(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonChip(String season) {
    final isSelected = _currentSeason == season;
    return GestureDetector(
      onTap: () => setState(() => _currentSeason = season),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppConfig.primaryGreen)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(AppConfig.primaryGreen)
                : const Color(AppConfig.primaryGreen).withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            season,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : const Color(AppConfig.textDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = _loanStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _loanStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppConfig.primaryGreen)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(AppConfig.primaryGreen)
                : const Color(AppConfig.primaryGreen).withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : const Color(AppConfig.textDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoanDoc,
  }) {
    final files = isLoanDoc ? _loanDocs : _ownershipDocs;

    return Column(
      children: [
        if (files.isNotEmpty)
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      style: GoogleFonts.inter(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () => _removeDocument(isLoanDoc, index),
                  ),
                ],
              ),
            );
          }).toList(),

        InkWell(
          onTap: () => _pickDocument(isLoanDoc),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(AppConfig.primaryGreen).withOpacity(0.2),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: const Color(AppConfig.primaryGreen),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConfig.textDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(AppConfig.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
