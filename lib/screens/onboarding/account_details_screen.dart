
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../login/service_selection_page.dart';

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

    setState(() => _isLoading = true);

    try {
      // Get Firebase authenticated user (set during OTP verification)
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        UIUtils.showError(context, 'Session expired. Please log in again.');
        return;
      }

      final userId = currentUser.uid;
      final phone = currentUser.phoneNumber;

      // Upload profile picture if selected
      String? photoUrl;
      if (_imageBytes != null && _imageExt != null) {
        photoUrl = await SupabaseService().uploadProfilePicture(
          userId,
          _imageBytes!,
          _imageExt!,
        );
      }

      // Upsert base profile in Supabase
      await SupabaseService().upsertUserProfile(
        userId: userId,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        phone: phone,
        profileImageUrl: photoUrl,
      );

      // Call the real create-account edge function
      try {
        final res = await SupabaseService().client.functions.invoke(
          'create-account',
          body: {
            'user_id': userId,
            'full_name': _nameController.text.trim(),
            'phone': phone,
            'email': _emailController.text.trim(),
            'city': _cityController.text.trim(),
            'photo_url': photoUrl ?? '',
          },
        );

        final data = res.data as Map<String, dynamic>? ?? {};

        if (data['success'] != true) {
          debugPrint('create-account returned: $data');
        }
      } catch (edgeFnError) {
        debugPrint('Edge function error: $edgeFnError');
      }

      // Save session locally
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UIUtils.showError(context, 'Error creating account: $e');
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
                          const SizedBox(height: 24),
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
