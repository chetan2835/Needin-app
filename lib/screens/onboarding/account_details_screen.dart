import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
      _showError('Please enter a 4-digit MPIN');
      return;
    }
    if (_mpin != _confirmMpin) {
      _showError('MPINs do not match');
      return;
    }

    setState(() => _isLoading = true);

    final phoneText = _phoneController.text.trim();
    final formattedPhone = "+91$phoneText";

    try {
      await AuthService().verifyPhoneNumber(
        phoneNumber: formattedPhone,
        codeSent: (verificationId) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showOtpBottomSheet(formattedPhone);
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showError('Verification failed: $error');
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error initiating verification: $e');
    }
  }

  void _showOtpBottomSheet(String formattedPhone) {
    String otp = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify Phone',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181411),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to $formattedPhone',
                style: const TextStyle(color: Color(0xFF8A7560), fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                onChanged: (val) => otp = val,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFFF8F7F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '000000',
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF27F0D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (otp.length == 6) {
                      _verifyOtpAndCreateAccount(otp, formattedPhone);
                    } else {
                      _showError("Invalid OTP length");
                    }
                  },
                  child: const Text(
                    'Verify & Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _verifyOtpAndCreateAccount(String otp, String phone) async {
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService().verifyOTP(otp);
      if (cred == null || cred.user == null) {
        setState(() => _isLoading = false);
        _showError('Invalid OTP');
        return;
      }

      final userId = cred.user!.uid;
      String? photoUrl;

      if (_imageBytes != null && _imageExt != null) {
        photoUrl = await SupabaseService().uploadProfilePicture(
          userId,
          _imageBytes!,
          _imageExt!,
        );
      }

      final response = await Supabase.instance.client.functions.invoke(
        'create-account',
        body: {
          'user_id': userId,
          'full_name': _nameController.text.trim(),
          'phone': phone,
          'email': _emailController.text.trim(),
          'city': _cityController.text.trim(),
          'mpin': _mpin,
          'photo_url': photoUrl,
        },
      );

      final data = response.data;
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
        _showError(data['error'] ?? 'Profile creation failed');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? prefixText,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFF27F0D)),
        prefixText: prefixText,
        counterText: "",
        filled: true,
        fillColor: const Color(0xFFF8F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF27F0D), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF27F0D)),
                )
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
                              color: Color(0xFF181411),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Set up your Needin Express identity.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF8A7560),
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
                                      color: Color(0xFFF27F0D),
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

                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.badge_rounded,
                            validator: (v) =>
                                v!.length < 2 ? 'Required valid name' : null,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
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

                          _buildTextField(
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

                          _buildTextField(
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
                                      color: Color(0xFFF27F0D),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Set Security MPIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF181411),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Enter 4-Digit MPIN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8A7560),
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
                                    color: Color(0xFF8A7560),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF27F0D),
                                elevation: 4,
                                shadowColor: const Color(
                                  0xFFF27F0D,
                                ).withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _submitData,
                              child: const Text(
                                'Complete Registration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
