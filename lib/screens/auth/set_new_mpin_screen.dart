import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/mpin_input_widget.dart';
import '../../core/services/local_storage_service.dart';
import '../login/service_selection_page.dart';

class SetNewMpinScreen extends StatefulWidget {
  final String userId;
  final String phoneNumber;

  const SetNewMpinScreen({
    super.key, 
    required this.userId,
    required this.phoneNumber,
  });

  @override
  State<SetNewMpinScreen> createState() => _SetNewMpinScreenState();
}

class _SetNewMpinScreenState extends State<SetNewMpinScreen> {
  String _mpin = "";
  String _confirmMpin = "";
  bool _isLoading = false;

  void _submitData() async {
    if (_mpin.length != 4 || _confirmMpin.length != 4) {
      _showError('Please enter a 4-digit MPIN');
      return;
    }
    if (_mpin != _confirmMpin) {
      _showError('MPINs do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upsert just uses create-account but without the other fields
      // Ensure your create-account gracefully ignores missing full_name
      final response = await Supabase.instance.client.functions.invoke(
        'set-mpin',
        body: {
          'user_id': widget.userId,
          'mpin': _mpin,
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        // Reload local session from response
        final u = data['user'];
        await LocalStorageService.saveUserSession(
          userId: u['id'],
          fullName: u['full_name'] ?? 'User',
          phone: u['phone'] ?? widget.phoneNumber,
          photoUrl: u['photo_url'],
          role: u['role'] ?? 'user',
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSelectionPage()),
          (r) => false,
        );
      } else {
        _showError(data['error'] ?? 'MPIN reset failed');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Set New MPIN', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text('Set Your MPIN *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                MpinInputWidget(
                  obscureText: true,
                  onChanged: (val) => _mpin = val,
                  onComplete: (val) => _mpin = val,
                ),
                const SizedBox(height: 24),
                
                const Text('Confirm MPIN *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                MpinInputWidget(
                  obscureText: true,
                  onChanged: (val) => _confirmMpin = val,
                  onComplete: (val) => _confirmMpin = val,
                ),
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF27F0D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitData,
                    child: const Text('SAVE MPIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
