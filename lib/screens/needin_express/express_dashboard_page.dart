import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/notification_bell.dart';
import 'express_profile_page.dart';
import 'post_journey_page.dart';
import 'sender_search_travelers_page.dart';

class ExpressDashboardPage extends StatefulWidget {
  const ExpressDashboardPage({super.key});

  @override
  State<ExpressDashboardPage> createState() => _ExpressDashboardPageState();
}

class _ExpressDashboardPageState extends State<ExpressDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).loadDashboardData();
      Provider.of<UserProfileProvider>(context, listen: false).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // gray-50
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            /// Sticky Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome back,",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B), // slate-500
                        ),
                      ),
                      const SizedBox(height: 2),
                      Consumer<UserProfileProvider>(
                        builder: (context, userProvider, child) {
                          final name = userProvider.firstName.isNotEmpty
                            ? userProvider.firstName
                            : 'User';
                          return Text(
                            "Hello, $name 👋",
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  Row(
                    children: [
                      // Notification bell with live badge
                      const NotificationBell(),
                      const SizedBox(width: 12),
                      /// Profile Avatar with online indicator
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => const ExpressProfilePage(),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Consumer<UserProfileProvider>(
                              builder: (context, userProvider, child) {
                                return _buildAvatar(userProvider.profileImageUrl);
                              },
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            /// Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    /// Main Two Buttons
                    Column(
                      children: [
                        /// Card 1: Traveler
                        DashboardCard(
                          backgroundColor: const Color(0xFFF05A4F), // primary
                          bgIcon: Icons.flight_takeoff,
                          icon: Icons.luggage,
                          iconBgColor: Colors.white.withValues(alpha: 0.2),
                          iconColor: Colors.white,
                          title: "EARN BY TRAVELLING",
                          titleColor: Colors.white,
                          description: "List your journey and earn by travelling.",
                          descriptionColor: Colors.white.withValues(alpha: 0.9),
                          buttonText: "Post a Journey",
                          buttonBgColor: Colors.white,
                          buttonTextColor: const Color(0xFFF05A4F),
                          onTap: () {
                            Navigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => const PostJourneyPage(),
                              ),
                            );
                          },
                        ),
    
                        const SizedBox(height: 16),
    
                        /// Card 2: Sender
                        DashboardCard(
                          backgroundColor: const Color(0xFF1E293B), // secondary-dark
                          bgIcon: Icons.inventory_2,
                          icon: Icons.directions_car,
                          iconBgColor: const Color(0xFF334155).withValues(alpha: 0.5),
                          iconColor: const Color(0xFFF05A4F),
                          title: "Search a Traveller",
                          titleColor: const Color(0xFFF1F5F9), // slate-100
                          description: "Ship your parcels safely through verified travellers.",
                          descriptionColor: const Color(0xFFCBD5E1),
                          buttonText: "Send a Parcel",
                          buttonBgColor: const Color(0xFF334155),
                          buttonTextColor: Colors.white,
                          buttonBorderColor: const Color(0xFF475569),
                          onTap: () {
                            Navigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => const SenderSearchTravelersPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }



  Widget _buildAvatar(String? url) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: Color(0xFF94A3B8),
                  size: 26,
                ),
              )
            : const Icon(
                Icons.person,
                color: Color(0xFF94A3B8),
                size: 26,
              ),
      ),
    );
  }
}


