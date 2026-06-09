import 'package:flutter/material.dart';
import '../../core/services/notification_service.dart';

/// ══════════════════════════════════════════════════════════════
///  NOTIFICATION PREFERENCES — User-configurable notification settings
/// ══════════════════════════════════════════════════════════════
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final NotificationService _service = NotificationService();
  Map<String, dynamic> _prefs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _service.getPreferences();
    if (mounted) setState(() { _prefs = prefs; _isLoading = false; });
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() => _prefs[key] = value);
    await _service.updatePreferences({key: value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Notification Settings', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F))))
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('General', [
                        _buildToggle('Push Notifications', 'push_enabled', Icons.notifications_active),
                        _buildToggle('In-App Notifications', 'in_app_enabled', Icons.chat),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Categories', [
                        _buildToggle('Messages', 'messages_enabled', Icons.message),
                        _buildToggle('Bookings & Journeys', 'bookings_enabled', Icons.luggage),
                        _buildToggle('Payments', 'payments_enabled', Icons.account_balance_wallet),
                        _buildToggle('Marketing & Offers', 'marketing_enabled', Icons.local_offer),
                        _buildToggle('Security Alerts', 'security_enabled', Icons.security),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Sound & Haptics', [
                        _buildToggle('Notification Sound', 'sound_enabled', Icons.volume_up),
                        _buildToggle('Vibration', 'vibration_enabled', Icons.vibration),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggle(String label, String key, IconData icon) {
    final value = _prefs[key] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFF05A4F).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: value ? const Color(0xFFF05A4F) : const Color(0xFF94A3B8), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
          Switch.adaptive(
            value: value,
            onChanged: (v) => _updatePref(key, v),
            activeTrackColor: const Color(0xFFF05A4F),
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ],
      ),
    );
  }
}
