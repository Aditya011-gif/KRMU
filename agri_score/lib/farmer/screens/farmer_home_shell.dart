import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import 'farmer_dashboard.dart';
import 'land_registration_screen.dart';
import 'document_upload_screen.dart';
import 'profile_screen.dart';

/// Shell widget that wraps the farmer screens with a BottomNavigationBar.
/// Tabs: Home | Land Details | Profile
class FarmerHomeShell extends StatefulWidget {
  const FarmerHomeShell({super.key});

  @override
  State<FarmerHomeShell> createState() => _FarmerHomeShellState();
}

class _FarmerHomeShellState extends State<FarmerHomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FarmerDashboard(),
    LandRegistrationScreen(),
    DocumentUploadScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.landscape_outlined,
                  activeIcon: Icons.landscape_rounded,
                  label: 'Land Details',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.file_copy_outlined,
                  activeIcon: Icons.file_copy_rounded,
                  label: 'Documents',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    const primary = Color(AppConfig.primaryGreen);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
