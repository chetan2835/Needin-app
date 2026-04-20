import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // gray-50
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
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
                          Consumer<AppProvider>(
                            builder: (context, provider, child) {
                              final profile = provider.userProfile;
                              final name = profile != null && profile['full_name'] != null 
                                ? profile['full_name'].toString().split(' ')[0] 
                                : 'Alex';
                              return Text(
                                "Hello, $name 👋",
                                style: const TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A), // slate-900
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      
                      /// Profile Avatar with online indicator
                      Stack(
                        children: [
                          Consumer<AppProvider>(
                            builder: (context, provider, child) {
                              final avatarUrl = provider.userProfile?['avatar_url'] ?? "https://lh3.googleusercontent.com/aida-public/AB6AXuDgqVAp0fSNciXhgbwpOY5P2bRxLNugIXMOuXp312yxIOZA5rBPdDVysaVqyHisPaXr7qu7Wbd19nQMUp7kcgGZVgCin5K1fGK8ur9m4X_wHtxszCRl7x5GEv8lLm3D9-cBCChKWZKFTSHgGzDIdmK0AK-xdPEsNsC8tp7DqvEhQsMC6XiC3hidDXWyiGp2o3HWTp4veagfloszLMeSI6lSVJNe_dJGelX436M80d-mEn3FuFDimPz_oitF67PHq9ZXw0MhNQt-0A";
                              return justifyAvatar(avatarUrl);
                            },
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E), // green-500
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // padding bottom for nav bar
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        /// Main Two Buttons
                        Column(
                          children: [
                            /// Card 1: Traveler
                            _buildDashboardCard(
                              context: context,
                              backgroundColor: const Color(0xFFF27F0D), // primary
                              bgIcon: Icons.flight_takeoff,
                              icon: Icons.luggage,
                              iconBgColor: Colors.white.withValues(alpha: 0.2),
                              iconColor: Colors.white,
                              title: "I AM A TRAVELER",
                              titleColor: Colors.white,
                              description: "Post your upcoming journey and earn by carrying parcels for senders.",
                              descriptionColor: Colors.white.withValues(alpha: 0.9),
                              buttonText: "Post a Journey",
                              buttonBgColor: Colors.white,
                              buttonTextColor: const Color(0xFFF27F0D),
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
                            _buildDashboardCard(
                              context: context,
                              backgroundColor: const Color(0xFF1E293B), // secondary-dark
                              bgIcon: Icons.inventory_2,
                              icon: Icons.local_shipping,
                              iconBgColor: const Color(0xFF334155).withValues(alpha: 0.5),
                              iconColor: const Color(0xFFF27F0D),
                              title: "I AM A SENDER",
                              titleColor: const Color(0xFFF1F5F9), // slate-100
                              description: "Need something delivered quickly? Send a parcel with a verified traveler.",
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
                        
                        const SizedBox(height: 32),
                        
                        /// Recent Activity Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Recent Activity",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // slate-900
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                "View All",
                                style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF27F0D), // primary
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Consumer<AppProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFFF27F0D)));
                            }
                            if (provider.recentParcels.isEmpty) {
                              return const Text("No recent parcels found.");
                            }
                            return Column(
                              children: provider.recentParcels.map((parcel) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildRecentActivityItem(
                                    icon: parcel.statusType == 'active' ? Icons.local_shipping : Icons.flight,
                                    iconBgColor: parcel.statusType == 'active' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                                    iconColor: parcel.statusType == 'active' ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                    title: parcel.title,
                                    statusBadgeText: parcel.statusBadgeText,
                                    statusBadgeBg: parcel.statusType == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    statusBadgeColor: parcel.statusType == 'active' ? const Color(0xFF15803D) : const Color(0xFF475569),
                                    subtitle: parcel.subtitle,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 32),

                        /// Explore Travelers Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Explore Travelers",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // slate-900
                              ),
                            ),
                            Row(
                              children: [
                                _buildArrowButton(Icons.arrow_back),
                                const SizedBox(width: 8),
                                _buildArrowButton(Icons.arrow_forward),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Horizontal scrollable travelers
                        SizedBox(
                          height: 180,
                          child: Consumer<AppProvider>(
                            builder: (context, provider, child) {
                              if (provider.isLoading) {
                                return const Center(child: CircularProgressIndicator(color: Color(0xFFF27F0D)));
                              }
                              
                              if (provider.popularJourneys.isEmpty) {
                                return const Center(child: Text("No active travelers at the moment."));
                              }

                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                clipBehavior: Clip.none,
                                itemCount: provider.popularJourneys.length,
                                itemBuilder: (context, index) {
                                  final journey = provider.popularJourneys[index];
                                  return Padding(
                                    padding: EdgeInsets.only(right: index == provider.popularJourneys.length - 1 ? 0 : 16.0),
                                    child: _buildTravelerCard(
                                      name: journey.driverName,
                                      rating: journey.driverRating,
                                      imgUrl: journey.driverAvatarUrl,
                                      origin: journey.origin,
                                      destination: journey.destination,
                                      capacity: journey.capacity,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            /// Bottom Nav
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(context, Icons.home_filled, "Home", true),
                    _buildNavButton(context, Icons.search, "Explore", false),
                    _buildNavButton(context, Icons.chat_bubble_outline, "Messages", false),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => const ExpressProfilePage(),
                          ),
                        );
                      },
                      child: _buildNavButton(context, Icons.person_outline, "Profile", false),
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

  Widget _buildRecentActivityItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String statusBadgeText,
    required Color statusBadgeBg,
    required Color statusBadgeColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 2xl
        border: Border.all(color: const Color(0xFFF1F5F9)), // slate-100
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusBadgeText,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusBadgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
      ),
      child: Center(
        child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)), // slate-400
      ),
    );
  }

  Widget _buildTravelerCard({
    required String name,
    required String rating,
    required String imgUrl,
    required String origin,
    required String destination,
    required String capacity,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 2xl
        border: Border.all(color: const Color(0xFFF1F5F9)), // slate-100
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(imgUrl),
                backgroundColor: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFEAB308), size: 14), // yellow-500
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.flight_takeoff, color: Color(0xFFF27F0D), size: 16),
              const SizedBox(width: 8),
              Text(
                origin,
                style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 12,
                  color: Color(0xFF475569), // slate-600
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flight_land, color: Color(0xFFF27F0D), size: 16),
              const SizedBox(width: 8),
              Text(
                destination,
                style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Available Space:",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  capacity,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFFF27F0D) : const Color(0xFF94A3B8), // primary or slate-400
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFFF27F0D) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
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

  Widget justifyAvatar(String url) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9), // slate-100
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

