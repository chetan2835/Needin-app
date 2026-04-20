import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'personal_info_page.dart';
import 'identity_verification_page.dart';
import 'my_journeys_page.dart';
import 'manage_payment_methods_page.dart';

import 'package:provider/provider.dart';
import '../../core/services/digilocker_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/language_service.dart';
import '../../core/providers/user_profile_provider.dart';
import '../login/login_page.dart';

class ExpressProfilePage extends StatefulWidget {
  const ExpressProfilePage({super.key});

  @override
  State<ExpressProfilePage> createState() => _ExpressProfilePageState();
}

class _ExpressProfilePageState extends State<ExpressProfilePage> {
  bool _isVerified = false;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // Real stats
  int _journeyCount = 0;
  int _parcelCount = 0;
  double _earnings = 0;

  // Notification settings
  bool _pushNotifs = true;
  bool _orderUpdates = true;
  bool _promoNotifs = false;
  bool _securityAlerts = true;
  bool _emailNotifs = true;
  bool _smsNotifs = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllData();
    });
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifs = prefs.getBool('notif_push') ?? true;
      _orderUpdates = prefs.getBool('notif_orders') ?? true;
      _promoNotifs = prefs.getBool('notif_promo') ?? false;
      _securityAlerts = prefs.getBool('notif_security') ?? true;
      _emailNotifs = prefs.getBool('notif_email') ?? true;
      _smsNotifs = prefs.getBool('notif_sms') ?? false;
    });
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _fetchAllData() async {
    final uid = AuthService().currentUser?.uid ?? '';
    final userProvider = Provider.of<UserProfileProvider>(context, listen: false);

    final results = await Future.wait([
      userProvider.loadProfile(), // Load global profile
      DigiLockerService().getStatus(),
      SupabaseService().getUserStats(uid),
    ]);

    final status = results[1] as DigiLockerStatus;
    final stats = results[2] as Map<String, dynamic>;

    if (mounted) {
      setState(() {
        _isVerified = status.isVerified;
        _journeyCount = stats['journeys'] as int? ?? 0;
        _parcelCount = stats['parcels'] as int? ?? 0;
        _earnings = (stats['earnings'] as num?)?.toDouble() ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final lang = LanguageService();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.t('logout'),
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.bold,
            )),
        content: Text(lang.t('logout_confirm'),
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('cancel'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontFamily: 'Plus Jakarta Sans',
                )),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.t('confirm'),
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    await LocalStorageService.clearSession();
    // Sign out from Firebase
    await AuthService().signOut();

    // Clear local session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seenOnboarding');
    // Keep MPIN but clear profile setup flag for clean re-login
    final keys = prefs.getKeys().where((k) => k.startsWith('profile_setup_complete_'));
    for (final key in keys) {
      await prefs.remove(key);
    }

    if (!mounted) return;

    // Navigate to login, clear entire navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showLanguagePicker() {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lang.t('select_language'),
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: LanguageService.supportedLanguages.length,
                itemBuilder: (ctx, i) {
                  final item = LanguageService.supportedLanguages[i];
                  final isSelected = item['code'] == lang.currentLocale;
                  return ListTile(
                    onTap: () async {
                      final nav = Navigator.of(ctx);
                      await lang.setLanguage(item['code']!);
                      if (mounted) {
                        nav.pop();
                        setState(() {}); // Rebuild with new language
                      }
                    },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF27F0D).withValues(alpha: 0.1)
                            : const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          item['code']!.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFFF27F0D)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      item['name']!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFF27F0D)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      item['native']!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFFF27F0D), size: 24)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings() {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  lang.t('notification_settings'),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildNotifToggle(lang.t('push_notifications'), _pushNotifs,
                        Icons.notifications_active, (v) {
                      setSheetState(() => _pushNotifs = v);
                      setState(() => _pushNotifs = v);
                      _saveNotifPref('notif_push', v);
                    }),
                    _buildNotifToggle(lang.t('order_updates'), _orderUpdates,
                        Icons.local_shipping, (v) {
                      setSheetState(() => _orderUpdates = v);
                      setState(() => _orderUpdates = v);
                      _saveNotifPref('notif_orders', v);
                    }),
                    _buildNotifToggle(lang.t('promotional'), _promoNotifs,
                        Icons.campaign, (v) {
                      setSheetState(() => _promoNotifs = v);
                      setState(() => _promoNotifs = v);
                      _saveNotifPref('notif_promo', v);
                    }),
                    _buildNotifToggle(lang.t('security_alerts'), _securityAlerts,
                        Icons.security, (v) {
                      setSheetState(() => _securityAlerts = v);
                      setState(() => _securityAlerts = v);
                      _saveNotifPref('notif_security', v);
                    }),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildNotifToggle(lang.t('email_notifications'), _emailNotifs,
                        Icons.email, (v) {
                      setSheetState(() => _emailNotifs = v);
                      setState(() => _emailNotifs = v);
                      _saveNotifPref('notif_email', v);
                    }),
                    _buildNotifToggle(lang.t('sms_notifications'), _smsNotifs,
                        Icons.sms, (v) {
                      setSheetState(() => _smsNotifs = v);
                      setState(() => _smsNotifs = v);
                      _saveNotifPref('notif_sms', v);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifToggle(
      String title, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF27F0D), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  )),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFFF27F0D),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSupport() {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lang.t('help_support'),
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildHelpItem(Icons.help_outline, lang.t('faq'), () {
              Navigator.pop(ctx);
              _showSnack('FAQ section coming soon');
            }),
            _buildHelpItem(Icons.email_outlined, lang.t('contact_us'), () {
              Navigator.pop(ctx);
              _showSnack('support@needinexpress.com');
            }),
            _buildHelpItem(Icons.bug_report_outlined, lang.t('report_issue'), () {
              Navigator.pop(ctx);
              _showSnack('Issue reporting coming soon');
            }),
            _buildHelpItem(Icons.description_outlined, lang.t('terms'), () {
              Navigator.pop(ctx);
              _showSnack('Terms of Service');
            }),
            _buildHelpItem(Icons.privacy_tip_outlined, lang.t('privacy_policy'), () {
              Navigator.pop(ctx);
              _showSnack('Privacy Policy');
            }),
            _buildHelpItem(Icons.info_outline, lang.t('about'), () {
              Navigator.pop(ctx);
              showAboutDialog(
                context: context,
                applicationName: 'Needin Express',
                applicationVersion: '2.4.0',
                applicationLegalese: '© 2024 Needin Express. All rights reserved.',
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFF27F0D), size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          )),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatEarnings(double amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final userProvider = Provider.of<UserProfileProvider>(context);
    final profile = userProvider.profileData;
    
    // Fallbacks or reactive properties
    final userName = profile?['full_name']?.toString() ?? 'User';
    final avatarUrl = profile?['profile_image_url']?.toString();
    final phone = profile?['phone']?.toString() ?? AuthService().currentUser?.phoneNumber ?? '';
    final email = profile?['email']?.toString() ?? '';
    final city = profile?['city']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27F0D)))
            : Stack(
                children: [
                  Column(
                    children: [
                      /// Header / Profile Section
                      Container(
                        color: Colors.white,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                      const Color(0xFFF27F0D).withValues(alpha: 0.02),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
                              child: Column(
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      Container(
                                        width: 100, height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                        child: avatarUrl == null || avatarUrl.isEmpty
                                            ? const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8))
                                            : ClipOval(
                                                child: Image.network(
                                                  avatarUrl,
                                                  key: UniqueKey(),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8)),
                                                ),
                                              ),
                                      ),
                                      if (_isVerified)
                                        Positioned(
                                          bottom: 4, right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
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
                                            child: const Icon(
                                              Icons.verified,
                                              color: Color(0xFFF27F0D),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Name
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Subtitle
                                  Text(
                                    city.isNotEmpty ? city : (email.isNotEmpty ? email : phone),
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Stats Bar
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F2F0),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildStatItem(lang.t('journeys'), '$_journeyCount', null),
                                        Container(width: 1, height: 40, color: const Color(0xFFE5E5E5)),
                                        _buildStatItem(lang.t('parcels'), '$_parcelCount', null),
                                        Container(width: 1, height: 40, color: const Color(0xFFE5E5E5)),
                                        _buildStatItem(lang.t('earnings'), _formatEarnings(_earnings), const Color(0xFFF27F0D)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// Menu List
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          children: [
                            // ACCOUNT section
                            _buildSectionHeader(lang.t('account')),
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
                                );
                                _fetchAllData(); // Refresh after editing
                              },
                              child: _buildMenuItem(
                                icon: Icons.person,
                                title: lang.t('personal_info'),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const MyJourneysPage()),
                                );
                              },
                              child: _buildMenuItem(
                                icon: Icons.luggage,
                                title: "My Journeys",
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(context,
                                  MaterialPageRoute(
                                    builder: (_) => const IdentityVerificationPage(),
                                  ),
                                );
                                if (result == true) _fetchAllData();
                              },
                              child: _buildMenuItem(
                                icon: Icons.badge,
                                title: lang.t('identity_verification'),
                                trailingWidget: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF08A),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    _isVerified ? lang.t('verified') : lang.t('pending'),
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: _isVerified ? const Color(0xFF15803D) : const Color(0xFFA16207),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context,
                                  MaterialPageRoute(
                                    builder: (_) => const ManagePaymentMethodsPage(),
                                  ),
                                );
                              },
                              child: _buildMenuItem(
                                icon: Icons.payment,
                                title: lang.t('payment_methods'),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // SETTINGS section
                            _buildSectionHeader(lang.t('settings')),
                            GestureDetector(
                              onTap: _showNotificationSettings,
                              child: _buildMenuItem(
                                icon: Icons.notifications,
                                title: lang.t('notification_settings'),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showLanguagePicker,
                              child: _buildMenuItem(
                                icon: Icons.language,
                                title: lang.t('language'),
                                trailingWidget: Text(
                                  lang.currentLanguageName,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showHelpSupport,
                              child: _buildMenuItem(
                                icon: Icons.support_agent,
                                title: lang.t('help_support'),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Logout Button
                            GestureDetector(
                              onTap: _isLoggingOut ? null : _handleLogout,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: _isLoggingOut
                                            ? const SizedBox(
                                                width: 20, height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              )
                                            : const Icon(Icons.logout,
                                                color: Color(0xFFDC2626), size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        lang.t('logout'),
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            Center(
                              child: Text(
                                "Version 2.4.0 • NEEDIN EXPRESS",
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),

                  /// Bottom Nav
                  Positioned(
                    bottom: 0, left: 0, right: 0,
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
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavButton(Icons.home_filled, lang.t('home'), false),
                          _buildNavButton(Icons.local_shipping, lang.t('orders'), false),
                          _buildNavButton(Icons.account_balance_wallet, lang.t('wallet'), false),
                          _buildNavButton(Icons.person, lang.t('profile'), true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color? valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              )),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailingWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: const Color(0xFFF27F0D), size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      )),
                ),
                if (trailingWidget != null) trailingWidget,
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: isActive ? const Color(0xFFF27F0D) : const Color(0xFF94A3B8),
            size: 24),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFFF27F0D) : const Color(0xFF94A3B8),
            )),
      ],
    );
  }
}
