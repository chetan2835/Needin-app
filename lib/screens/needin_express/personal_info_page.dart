import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/services/language_service.dart';
import '../../core/services/local_storage_service.dart';
import '../login/email_otp_page.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _ageController;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _existingAvatarUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;
  final ImagePicker _picker = ImagePicker();

  String? _nameError;
  String? _emailError;
  String? _cityError;
  String? _ageError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _cityController = TextEditingController();
    _ageController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userProfileProv = Provider.of<UserProfileProvider>(context, listen: false);
    await userProfileProv.loadProfile();
    final profile = userProfileProv.profileData;

    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name']?.toString() ?? '';
        _emailController.text = profile['email']?.toString() ?? '';
        _cityController.text = profile['city']?.toString() ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _existingAvatarUrl = profile['profile_image_url']?.toString();
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExt = ext.isNotEmpty ? ext : 'jpg';
        });
      }
    } catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  Future<void> _verifyEmailFlow() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter an email address first', isError: true);
      return;
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showSnack('Please enter a valid email format', isError: true);
      return;
    }

    // CRITICAL FIX: Save the email to the DB first!
    // The OTP verification relies on a Supabase RLS policy that matches the row
    // using (email = auth.email()). If the row doesn't have the email yet,
    // the OTP update will fail silently with 0 rows affected.
    final userProfileProv = Provider.of<UserProfileProvider>(context, listen: false);
    await userProfileProv.updateProfile(email: email);

    if (!mounted) return;
    final success = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmailOtpPage(email: email)),
    );

    if (success == true && mounted) {
      // Optimistic in-memory update (immediate badge rendering)
      userProfileProv.markEmailVerified(email);
      // Re-fetch from backend to confirm persistence (source of truth sync)
      userProfileProv.loadProfile();
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final city = _cityController.text.trim();
    final ageStr = _ageController.text.trim();

    setState(() {
      _nameError = null;
      _emailError = null;
      _cityError = null;
      _ageError = null;
    });

    bool hasError = false;

    if (name.isEmpty) {
      _nameError = 'Full name is required';
      hasError = true;
    }
    if (city.isEmpty) {
      _cityError = 'City is required';
      hasError = true;
    }
    if (ageStr.isEmpty) {
      _ageError = 'Age is required';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);
    
    final userProviders = Provider.of<UserProfileProvider>(context, listen: false);
    
    // Only save email if it's NOT verified yet.
    // Verified emails are locked and cannot be overridden by profile saves.
    final emailToSave = userProviders.isEmailVerified ? null : email;

    // CRITICAL FIX: Always write Firebase phone number to profiles.phone.
    // Without this, profiles.phone is null and the Call feature cannot
    // prefill the traveler's number in the dialer.
    final firebasePhone = AuthService().currentUser?.phoneNumber;

    final success = await userProviders.updateProfile(
      fullName: name,
      email: emailToSave,
      city: city,
      age: int.tryParse(ageStr),
      phone: firebasePhone, // always persist Firebase phone to DB
      imageBytes: _selectedImageBytes,
      imageExt: _selectedImageExt,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      await LocalStorageService.setProfileCompleted();
      if (!mounted) return;
      _showSnack('Profile updated successfully!');
      Navigator.pop(context);
    } else {
      _showSnack('Failed to save. Please try again. ${userProviders.error}', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('personal_details'),
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFF3F4F6), height: 1.0),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F)))
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Photo section
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 128,
                                        height: 128,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE5E7EB),
                                          border: Border.all(color: Colors.white, width: 4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _selectedImageBytes != null
                                              ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover,
                                                  width: 128, height: 128)
                                              : (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty
                                                  ? Image.network(_existingAvatarUrl!, key: UniqueKey(), fit: BoxFit.cover,
                                                      width: 128, height: 128,
                                                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8)))
                                                  : const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8))),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4, right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF05A4F),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Text(
                                    lang.t('change_photo'),
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF05A4F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Form fields
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  label: lang.t('full_name'),
                                  controller: _nameController,
                                  icon: Icons.person,
                                  errorText: _nameError,
                                  onChanged: (_) {
                                    if (_nameError != null) setState(() => _nameError = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                // Email field: locked when verified
                                Builder(builder: (context) {
                                  final isVerified = context.watch<UserProfileProvider>().isEmailVerified;
                                  return _buildTextField(
                                    label: "Email Address",
                                    controller: _emailController,
                                    icon: Icons.mail,
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: _emailError,
                                    readOnly: isVerified,
                                    onChanged: (_) {
                                      if (_emailError != null) setState(() => _emailError = null);
                                    },
                                    trailing: isVerified
                                        ? const Padding(
                                            padding: EdgeInsets.only(right: 12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Verified",
                                                  style: TextStyle(
                                                    color: Color(0xFF16A34A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    fontFamily: 'Plus Jakarta Sans',
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                                              ],
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: _verifyEmailFlow,
                                            child: const Text(
                                              "Verify Email",
                                              style: TextStyle(
                                                color: Color(0xFFF05A4F),
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  );
                                }),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  label: "City",
                                  controller: _cityController,
                                  icon: Icons.location_on,
                                  errorText: _cityError,
                                  onChanged: (_) {
                                    if (_cityError != null) setState(() => _cityError = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  label: "Age",
                                  controller: _ageController,
                                  icon: Icons.cake,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  errorText: _ageError,
                                  onChanged: (_) {
                                    if (_ageError != null) setState(() => _ageError = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  label: lang.t('phone_number'),
                                  controller: TextEditingController(text: AuthService().currentUser?.phoneNumber ?? ''),
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  readOnly: true,
                                  trailing: const Padding(
                                    padding: EdgeInsets.only(right: 16.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                        SizedBox(width: 4),
                                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Save button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF05A4F),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSaving ? null : _saveChanges,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  lang.t('save_changes'),
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? errorText,
    ValueChanged<String>? onChanged,
    Widget? trailing,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: trailing ?? (readOnly
                  ? const Icon(Icons.lock_outline, color: Color(0xFFCBD5E1), size: 18)
                  : null),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
      ],
    );
  }
}
