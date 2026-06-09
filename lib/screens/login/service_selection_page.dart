import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/services/local_storage_service.dart';
import '../needin_express/express_dashboard_page.dart';
import 'profile_setup_page.dart';
import 'coming_soon_page.dart';

class ServiceSelectionPage extends StatelessWidget {
  const ServiceSelectionPage({super.key});

  /// Show a premium animated profile completion gate popup
  void _showProfileGatePopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Mandatory
      barrierLabel: 'Profile Gate',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * anim1.value,
            sigmaY: 6 * anim1.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: anim1,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                child: _ProfileGateContent(
                  onCompleteProfile: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const ProfileSetupPage(),
                        transitionsBuilder: (_, anim, __, child) =>
                            SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.15),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: anim,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleServiceTap(BuildContext context, Widget destination) async {
    final profileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );

    // Immediate check if provider already knows it's complete
    if (profileProvider.isProfileComplete) {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      return;
    }

    // Fallback: Check persistent local storage in case provider is still loading
    final isLocallyComplete = await LocalStorageService.isProfileCompleted();
    if (isLocallyComplete) {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      return;
    }

    // If both say incomplete, show popup
    if (!context.mounted) return;
    _showProfileGatePopup(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5), // background-light
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 30, // 3xl
                        fontWeight: FontWeight.w800, // extrabold
                        color: Color(0xFF0F172A), // slate-900
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(text: "Choose Your\n"),
                        TextSpan(
                          text: "Service",
                          style: TextStyle(color: Color(0xFFF05A4F)), // primary
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// Main Content Area: Vertical Cards
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  /// Card 1: NEEDIN EXPRESS
                  _buildServiceCard(
                    context: context,
                    backgroundColor: const Color(0xFFF05A4F), // primary
                    bgIconWidget: const Icon(
                      Icons.flight_takeoff,
                      size: 200,
                      color: Colors.white,
                    ),
                    iconWidget: const Icon(
                      Icons.luggage,
                      color: Colors.white,
                      size: 32,
                    ),
                    iconBgColor: Colors.white.withValues(alpha: 0.2),
                    title: "NEEDIN EXPRESS",
                    titleColor: Colors.white,
                    description:
                        "Logistics Marketplace for Travelers & Senders. Fast, peer-to-peer delivery.",
                    descriptionColor: Colors.white.withValues(alpha: 0.9),
                    buttonText: "Enter Express",
                    buttonBgColor: Colors.white,
                    buttonTextColor: const Color(0xFFF05A4F),
                    onTap: () => _handleServiceTap(
                      context,
                      const ExpressDashboardPage(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Card 2: NEEDIN SERVICES
                  _buildServiceCard(
                    context: context,
                    backgroundColor: const Color(0xFF1E293B), // secondary-dark
                    bgIconWidget: Opacity(
                      opacity: 0.1,
                      child: Image.asset(
                        'assets/images/vendor_logo.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    iconWidget: Image.asset(
                      'assets/images/vendor_logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    iconBgColor: Colors.white,
                    title: "NEEDIN SERVICES",
                    titleColor: const Color(0xFFF1F5F9), // slate-100
                    description:
                        "Verified Professionals and Trusted House Help at your Door Step",
                    descriptionColor: const Color(0xFFCBD5E1), // slate-300
                    buttonText: "Enter Services",
                    buttonBgColor: const Color(0xFF334155), // slate-700
                    buttonTextColor: Colors.white,
                    buttonBorderColor: const Color(0xFF475569), // slate-600
                    onTap: () =>
                        _handleServiceTap(context, const ComingSoonPage()),
                  ),

                  const SizedBox(height: 16), // Bottom padding equivalent
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required Color backgroundColor,
    required Widget bgIconWidget,
    required Widget iconWidget,
    required Color iconBgColor,
    required String title,
    required Color titleColor,
    required String description,
    required Color descriptionColor,
    required String buttonText,
    required Color buttonBgColor,
    required Color buttonTextColor,
    Color? buttonBorderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24), // 2xl
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background Icon
            Positioned(
              right: -30,
              bottom: -40,
              child: Opacity(opacity: 0.15, child: bgIconWidget),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Left Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12), // xl
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: iconWidget,
                      ),

                      // Top Right Arrow
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_outward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom Content
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24, // 2xl
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0, // tracking-wider
                      color: titleColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width:
                        MediaQuery.of(context).size.width *
                        0.6, // max-w-[85%] equivalent approx
                    child: Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, // sm
                        fontWeight: FontWeight.w500, // medium
                        color: descriptionColor,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ), // px-5 py-2.5
                    decoration: BoxDecoration(
                      color: buttonBgColor,
                      borderRadius: BorderRadius.circular(8), // lg
                      border: buttonBorderColor != null
                          ? Border.all(color: buttonBorderColor)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonText,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14, // sm
                            fontWeight: FontWeight.bold,
                            color: buttonTextColor,
                          ),
                        ),
                        const SizedBox(width: 8), // gap-2
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: buttonTextColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Premium Profile Completion Gate Popup Content
// ══════════════════════════════════════════════════════════════

class _ProfileGateContent extends StatelessWidget {
  final VoidCallback onCompleteProfile;

  const _ProfileGateContent({required this.onCompleteProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF05A4F).withValues(alpha: 0.15),
                  const Color(0xFFF05A4F).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFF05A4F),
                size: 36,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Profile Setup Required',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),

          // Description
          const Text(
            'Before using this service, please complete your profile details.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          // Complete Profile button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A4F),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onCompleteProfile,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Complete Now',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
