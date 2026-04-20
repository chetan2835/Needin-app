import 'package:flutter/material.dart';
import '../needin_express/express_dashboard_page.dart';
import 'coming_soon_page.dart';

class ServiceSelectionPage extends StatelessWidget {
  const ServiceSelectionPage({super.key});

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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: Color(0xFF0F172A), // slate-900
                        ),
                      ),
                    ),
                  ),
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
                          style: TextStyle(color: Color(0xFFF27F0D)), // primary
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  /// Card 1: NEEDIN EXPRESS
                  _buildServiceCard(
                    context: context,
                    backgroundColor: const Color(0xFFF27F0D), // primary
                    bgIcon: Icons.flight_takeoff,
                    icon: Icons.luggage,
                    iconBgColor: Colors.white.withValues(alpha: 0.2),
                    iconColor: Colors.white,
                    title: "NEEDIN EXPRESS",
                    titleColor: Colors.white,
                    description: "Logistics Marketplace for Travelers & Senders. Fast, peer-to-peer delivery.",
                    descriptionColor: Colors.white.withValues(alpha: 0.9),
                    buttonText: "Enter Express",
                    buttonBgColor: Colors.white,
                    buttonTextColor: const Color(0xFFF27F0D),
                    onTap: () {
                      Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const ExpressDashboardPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// Card 2: NEEDIN VENDOR
                  _buildServiceCard(
                    context: context,
                    backgroundColor: const Color(0xFF1E293B), // secondary-dark
                    bgIcon: Icons.warehouse,
                    icon: Icons.local_shipping,
                    iconBgColor: const Color(0xFF334155).withValues(alpha: 0.5), // slate-700/50
                    iconColor: const Color(0xFFF27F0D), // primary
                    title: "NEEDIN VENDOR",
                    titleColor: const Color(0xFFF1F5F9), // slate-100
                    description: "Professional Logistics & B2B Solutions. Manage fleets and large cargo.",
                    descriptionColor: const Color(0xFFCBD5E1), // slate-300
                    buttonText: "Enter Vendor",
                    buttonBgColor: const Color(0xFF334155), // slate-700
                    buttonTextColor: Colors.white,
                    buttonBorderColor: const Color(0xFF475569), // slate-600
                    onTap: () {
                      Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const ComingSoonPage(),
                        ),
                      );
                    },
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
    required IconData bgIcon,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
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
              child: Opacity(
                opacity: 0.15,
                child: Icon(
                  bgIcon,
                  size: 200,
                  color: Colors.white,
                ),
              ),
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
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 32,
                        ),
                      ),
                      
                      // Top Right Arrow
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                    width: MediaQuery.of(context).size.width * 0.6, // max-w-[85%] equivalent approx
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // px-5 py-2.5
                    decoration: BoxDecoration(
                      color: buttonBgColor,
                      borderRadius: BorderRadius.circular(8), // lg
                      border: buttonBorderColor != null ? Border.all(color: buttonBorderColor) : null,
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
