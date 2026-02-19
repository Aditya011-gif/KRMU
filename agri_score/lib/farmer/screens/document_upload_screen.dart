import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';

/// Screen for uploading Land Ownership, Loan Statement & KYC documents.
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final List<PlatformFile> _landDocs = [];
  final List<PlatformFile> _loanDocs = [];
  final List<PlatformFile> _kycDocs = [];
  bool _isSubmitting = false;

  // ── File picker ──────────────────────────────────────────────
  Future<void> _pickFiles(_DocCategory category) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() => _listFor(category).addAll(result.files));
      }
    } catch (e) {
      _snackbar('Error picking file: $e', isError: true);
    }
  }

  void _removeFile(_DocCategory category, int index) {
    setState(() => _listFor(category).removeAt(index));
  }

  List<PlatformFile> _listFor(_DocCategory c) {
    switch (c) {
      case _DocCategory.land:
        return _landDocs;
      case _DocCategory.loan:
        return _loanDocs;
      case _DocCategory.kyc:
        return _kycDocs;
    }
  }

  // ── Submit ──────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_landDocs.isEmpty && _loanDocs.isEmpty && _kycDocs.isEmpty) {
      _snackbar('Please upload at least one document', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate upload delay (actual Supabase Storage integration can be added later)
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isSubmitting = false);
    _snackbar(
      '${_landDocs.length + _loanDocs.length + _kycDocs.length} document(s) submitted successfully!',
    );
  }

  void _snackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: isError
            ? const Color(AppConfig.dangerRed)
            : const Color(AppConfig.primaryGreen),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              AppConfig.primaryGreen,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Color(AppConfig.primaryGreen),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Documents',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(AppConfig.textDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Land records, loan statements & KYC',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(AppConfig.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress indicator
                    _buildProgressBar(),
                  ],
                ),
              ),
            ),

            // ── Section 1: Land Documents ──
            _buildSection(
              icon: Icons.terrain_rounded,
              title: 'Land Ownership Documents',
              subtitle: 'Title deed, land records, Khasra/Khatauni',
              category: _DocCategory.land,
              color: const Color(AppConfig.primaryGreen),
              bgColor: const Color(0xFFE8F5E9),
            ),

            // ── Section 2: Loan Statements ──
            _buildSection(
              icon: Icons.account_balance_rounded,
              title: 'Previous Loan Statements',
              subtitle: 'Bank loan PDFs, repayment receipts',
              category: _DocCategory.loan,
              color: const Color(AppConfig.accentAmber),
              bgColor: const Color(0xFFFFF8E1),
            ),

            // ── Section 3: KYC Documents ──
            _buildSection(
              icon: Icons.badge_rounded,
              title: 'KYC Documents',
              subtitle: 'Aadhaar card, PAN card, Voter ID',
              category: _DocCategory.kyc,
              color: Colors.blue.shade700,
              bgColor: Colors.blue.shade50,
            ),

            // ── Submit Button ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConfig.primaryGreen),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        AppConfig.primaryGreen,
                      ).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_done_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Submit All Documents',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress indicator ──────────────────────────────────────
  Widget _buildProgressBar() {
    final total = 3;
    int filled = 0;
    if (_landDocs.isNotEmpty) filled++;
    if (_loanDocs.isNotEmpty) filled++;
    if (_kycDocs.isNotEmpty) filled++;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$filled of $total categories uploaded',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConfig.textDark),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: filled / total,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      filled == total
                          ? const Color(AppConfig.primaryGreen)
                          : const Color(AppConfig.accentAmber),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: filled == total
                  ? const Color(AppConfig.primaryGreen).withOpacity(0.1)
                  : const Color(AppConfig.accentAmber).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(filled / total * 100).toInt()}%',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled == total
                    ? const Color(AppConfig.primaryGreen)
                    : const Color(AppConfig.accentAmber),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section builder ─────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required _DocCategory category,
    required Color color,
    required Color bgColor,
  }) {
    final files = _listFor(category);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
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
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(AppConfig.textDark),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(AppConfig.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (files.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${files.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Picked files list
              if (files.isNotEmpty) ...[
                ...files.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  final ext = file.extension?.toLowerCase() ?? '';
                  final isPdf = ext == 'pdf';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isPdf
                                ? Colors.red.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            color: isPdf
                                ? Colors.red.shade400
                                : Colors.blue.shade400,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(AppConfig.textDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (file.size > 0)
                                Text(
                                  _formatFileSize(file.size),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(AppConfig.textMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeFile(category, index),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
              ],

              // Upload tap area
              InkWell(
                onTap: () => _pickFiles(category),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: bgColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.add_rounded, color: color, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        files.isEmpty ? 'Tap to upload' : 'Add more files',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF, JPG, PNG supported',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(AppConfig.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

enum _DocCategory { land, loan, kyc }
