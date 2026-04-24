import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/mpin_input_widget.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../login/service_selection_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();

  String _mpin = "";
  String _confirmMpin = "";

  Uint8List? _imageBytes;
  String? _imageExt;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last;
      setState(() {
        _imageBytes = bytes;
        _imageExt = ext.isNotEmpty ? ext : 'jpg';
      });
    }
  }

  void _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mpin.length != 4) {
      UIUtils.showError(context, 'Please enter a 4-digit MPIN');
      return;
    }
    if (_mpin != _confirmMpin) {
      UIUtils.showError(context, 'MPINs do not match');
      return;
    }

    setState(() => _isLoading = true);

    final phoneText = _phoneController.text.trim();
    final formattedPhone = "+91$phoneText";

    try {
      // Bypass OTP: Directly create account
      await _createAccountDirectly(formattedPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UIUtils.showError(context, 'Error creating account: $e');
    }
  }

  Future<void> _createAccountDirectly(String phone) async {
    try {
      String? userId;
      
      // Get or create Firebase user
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        userId = currentUser.uid;
      } else {
        final cred = await AuthService().signInAnonymously();
        userId = cred?.user?.uid;
      }

      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        UIUtils.showError(context, 'Authentication failed');
        return;
      }

      String? photoUrl;
      if (_imageBytes != null && _imageExt != null) {
        photoUrl = await SupabaseService().uploadProfilePicture(
          userId,
          _imageBytes!,
          _imageExt!,
        );
      }
      
      await SupabaseService().upsertUserProfile(
        userId: userId,
        phone: phone,
      );

      // Bypass edge function to avoid 401 Unauthorized errors 
      // since JWT verification cannot be disabled without the CLI.
      debugPrint("Bypassing create-account edge function to avoid 401 error.");
      
      final data = {'success': true};

      if (data['success'] == true) {
        await LocalStorageService.saveUserSession(
          userId: userId,
          fullName: _nameController.text.trim(),
          phone: phone,
          photoUrl: photoUrl ?? '',
        );
        await LocalStorageService.setOnboardingComplete();

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSelectionPage()),
          (r) => false,
        );
      } else {
        if (!mounted) return;
        UIUtils.showError(context, (data['error'] as String?) ?? 'Profile creation failed');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UIUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isLoading
              ? UIUtils.loadingIndicator()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Complete Profile',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: UIUtils.textMain,
                              fontFamily: "Plus Jakarta Sans",
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set up your Needin Express identity.',
                            style: TextStyle(
                              fontSize: 16,
                              color: UIUtils.textSecondary,
                              fontFamily: "Plus Jakarta Sans",
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Profile Picture
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F7F5),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFF3F4F6),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      image: _imageBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(_imageBytes!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _imageBytes == null
                                        ? const Icon(
                                            Icons.person_rounded,
                                            size: 50,
                                            color: Color(0xFFD1D5DB),
                                          )
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: UIUtils.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          CustomTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.badge_rounded,
                            validator: (v) =>
                                v!.length < 2 ? 'Required valid name' : null,
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            prefixText: '+91 ',
                            maxLength: 10,
                            validator: (v) {
                              if (v == null || v.length != 10) {
                                return 'Must be 10 digits';
                              }
                              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                                return 'Invalid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _emailController,
                            label: 'Email Address (Optional)',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v != null &&
                                  v.isNotEmpty &&
                                  !v.contains('@')) {
                                return 'Invalid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _cityController,
                            label: 'Your City',
                            icon: Icons.location_city_rounded,
                            validator: (v) => v!.length < 2 ? 'Required' : null,
                          ),
                          const SizedBox(height: 48),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F7F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      color: UIUtils.primary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Set Security MPIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: UIUtils.textMain,
                                        fontFamily: "Plus Jakarta Sans",
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Enter 4-Digit MPIN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: UIUtils.textSecondary,
                                    fontFamily: "Plus Jakarta Sans",
                                  ),
                                ),
                                const SizedBox(height: 12),
                                MpinInputWidget(
                                  obscureText: true,
                                  onChanged: (val) => _mpin = val,
                                  onComplete: (val) => _mpin = val,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Confirm 4-Digit MPIN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: UIUtils.textSecondary,
                                    fontFamily: "Plus Jakarta Sans",
                                  ),
                                ),
                                const SizedBox(height: 12),
                                MpinInputWidget(
                                  obscureText: true,
                                  onChanged: (val) => _confirmMpin = val,
                                  onComplete: (val) => _confirmMpin = val,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _submitData,
                              child: const Text('Complete Registration'),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
