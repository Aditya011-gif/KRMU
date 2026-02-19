import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../models/fraud_risk_model.dart';
import '../../providers/fraud_risk_provider.dart';

/// Full‑page detail screen for the Fraud Risk Engine output.
class FraudRiskDetailScreen extends ConsumerWidget {
  const FraudRiskDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(fraudRiskProvider);
    final catColor = Color(result.fraudRiskCategory.color);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(AppConfig.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fraud Risk Analysis',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(AppConfig.textDark),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          children: [
            // ── Score Gauge Card ──
            _buildScoreCard(result, catColor),
            const SizedBox(height: 16),

            // ── Manual Review Banner ──
            if (result.manualReviewRequired) ...[
              _buildReviewBanner(),
              const SizedBox(height: 16),
            ],

            // ── Rules Breakdown ──
            _buildRulesCard(result),
          ],
        ),
      ),
    );
  }

  // ── Score Card ────────────────────────────────────────────
  Widget _buildScoreCard(FraudRiskResult result, Color catColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: catColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular gauge
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: result.fraudRiskScore / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(catColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${result.fraudRiskScore}',
                      style: GoogleFonts.outfit(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: catColor,
                      ),
                    ),
                    Text(
                      'out of 100',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(AppConfig.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  result.fraudRiskCategory == FraudRiskCategory.low
                      ? Icons.verified_rounded
                      : result.fraudRiskCategory == FraudRiskCategory.moderate
                      ? Icons.warning_amber_rounded
                      : Icons.gpp_bad_rounded,
                  color: catColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${result.fraudRiskCategory.label} Risk',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            result.isClean
                ? 'No fraud indicators detected. All integrity checks passed.'
                : '${result.triggeredRules.length} of 4 integrity rules triggered.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(AppConfig.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual Review Banner ──────────────────────────────────
  Widget _buildReviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(AppConfig.accentAmber).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(AppConfig.accentAmber).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.rate_review_rounded,
              color: Color(AppConfig.accentAmber),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Review Required',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConfig.textDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This application has been flagged for additional verification by an officer.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(AppConfig.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rules Card ────────────────────────────────────────────
  Widget _buildRulesCard(FraudRiskResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Rule Breakdown',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(AppConfig.textDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FRS = Σ (wᵢ × Rᵢ) — each triggered rule adds its weight to the score.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(AppConfig.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          // Each rule
          ...FraudRule.values.map(
            (rule) => _buildRuleRow(rule, result.triggeredRules.contains(rule)),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(FraudRule rule, bool triggered) {
    final color = triggered
        ? const Color(AppConfig.dangerRed)
        : const Color(AppConfig.primaryGreen);
    final bgColor = triggered ? Colors.red.shade50 : const Color(0xFFE8F5E9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              triggered ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rule.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(AppConfig.textDark),
                        ),
                      ),
                    ),
                    // Weight badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'w = ${rule.weight}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rule.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(AppConfig.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
