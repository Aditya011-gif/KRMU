import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';

/// Color-coded risk badge widget.
class RiskBadge extends StatelessWidget {
  final String category;
  final double? fontSize;

  const RiskBadge({super.key, required this.category, this.fontSize});

  Color get _color {
    switch (category) {
      case 'Low':
        return const Color(AppConfig.primaryGreen);
      case 'Medium':
        return const Color(AppConfig.accentAmber);
      case 'High':
        return const Color(AppConfig.dangerRed);
      case 'Flagged':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String get _label {
    switch (category) {
      case 'Low':
        return '🟢 Low Risk';
      case 'Medium':
        return '🟡 Medium Risk';
      case 'High':
        return '🔴 High Risk';
      case 'Flagged':
        return '🚩 Flagged';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: GoogleFonts.inter(
          fontSize: fontSize ?? 14,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
