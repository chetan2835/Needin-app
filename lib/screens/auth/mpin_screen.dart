import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/mpin_input_widget.dart';
import '../login/service_selection_page.dart';
import '../login/login_page.dart';

class MpinScreen extends StatefulWidget {
  const MpinScreen({super.key});

  @override
  State<MpinScreen> createState() => _MpinScreenState();
}

class _MpinScreenState extends State<MpinScreen> with SingleTickerProviderStateMixin {
  String? _userName;
  String? _photoUrl;
  String? _userId;

  bool _isLoading = false;
  bool _isLocked = false;
  int _lockedSeconds = 0;
  String? _errorMessage;
  Timer? _lockTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reset();
        }
      });
    
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await LocalStorageService.getUserName();
    final photo = await LocalStorageService.getUserPhoto();
    final id = await LocalStorageService.getUserId();
    if (mounted) {
      setState(() {
        _userName = name ?? 'User';
        _photoUrl = photo;
        _userId = id;
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockdown(int seconds) {
    if (!mounted) return;
    setState(() {
      _isLocked = true;
      _lockedSeconds = seconds;
      _errorMessage = null;
    });

    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_lockedSeconds > 0) {
          _lockedSeconds--;
        } else {
          _isLocked = false;
          timer.cancel();
        }
      });
    });
  }

  void _verifyMpin(String mpin) async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'verify-mpin',
        body: {'user_id': _userId, 'mpin': mpin},
      );
      
      final data = res.data;

      if (data['success'] == true) {
        // Update local session
        final u = data['user'];
        await LocalStorageService.saveUserSession(
          userId: u['id'],
          fullName: u['full_name'],
          phone: u['phone'],
          photoUrl: u['photo_url'],
          role: u['role'],
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSelectionPage()),
        );
      } else {
        if (!mounted) return;
        _shakeController.forward();
        
        if (data['locked'] == true) {
          int wait = data['wait_seconds'] ?? 30;
          _startLockdown(wait);
        } else {
          setState(() {
            _errorMessage = data['error'] ?? 'Incorrect MPIN';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _forgotMpin() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset MPIN'),
          content: const Text("To reset your MPIN, we'll send an OTP to your registered phone number. We will redirect you to the login screen."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await LocalStorageService.clearSession();
                await AuthService().signOut();
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Cannot go back
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64),
                
                // Profile Photo
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) 
                      ? CachedNetworkImageProvider(_photoUrl!) 
                      : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                
                const Text('Welcome back,', style: TextStyle(fontSize: 16, color: Colors.grey)),
                Text(
                  _userName ?? '',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                
                const SizedBox(height: 48),
                const Text('Enter your MPIN to continue', style: TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 24),
                
                // Animated MPIN input
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          _shakeAnimation.isAnimating 
                              ? (_shakeAnimation.value % 20 < 10 ? _shakeAnimation.value : 20 - _shakeAnimation.value) - 5
                              : 0, 
                          0),
                      child: child,
                    );
                  },
                  child: IgnorePointer(
                    ignoring: _isLocked || _isLoading,
                    child: Opacity(
                      opacity: _isLocked ? 0.5 : 1.0,
                      child: Center(
                         child: MpinInputWidget(
                            onComplete: _verifyMpin,
                            onChanged: (v) {},
                            obscureText: true,
                         ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                
                if (_isLoading) 
                  const CircularProgressIndicator()
                else if (_isLocked)
                  Text(
                    'Too many attempts. Try again in ${_lockedSeconds}s',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                  ),

                const Spacer(),
                
                TextButton(
                  onPressed: _isLoading || _isLocked ? null : _forgotMpin,
                  child: const Text('Forgot MPIN?', style: TextStyle(color: Colors.blue)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
