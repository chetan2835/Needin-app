import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_profile_provider.dart';
import '../needin_express/identity_verification_page.dart';
import 'email_otp_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;
  
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;
  String? _existingAvatarUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final userProfileProv = Provider.of<UserProfileProvider>(context, listen: false);
    await userProfileProv.loadProfile();
    final profile = userProfileProv.profileData;
    
    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _cityController.text = profile['city'] ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _existingAvatarUrl = profile['profile_image_url'];
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExt = ext.isNotEmpty ? ext : 'jpg';
        });
      }
    } catch (e) {
      debugPrint("Failed to pick image: $e");
    }
  }

  Future<void> _verifyEmailFlow() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter an email address first")));
      return;
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email format")),
      );
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
      // Optimistic in-memory update — instant badge rendering
      userProfileProv.markEmailVerified(email);
      // Re-fetch to confirm DB persistence in background
      userProfileProv.loadProfile();
    }
  }

  /// Save profile — only include email if not yet verified.
  /// If already verified, the email field is locked and must not be sent
  /// (to prevent accidentally clearing email_verified in any edge case).
  Future<void> _doSaveProfile(BuildContext ctx) async {
    final userProviders = Provider.of<UserProfileProvider>(ctx, listen: false);
    final emailToSave = userProviders.isEmailVerified ? null : _emailController.text.trim();

    // CRITICAL FIX: Always write the Firebase phone number to profiles table.
    // The phone is the user's primary identity (Firebase Auth).
    // Without this, profiles.phone is null and the Call feature cannot
    // prefill the traveler's number in the dialer.
    final firebasePhone = AuthService().currentUser?.phoneNumber;

    final success = await userProviders.updateProfile(
      fullName: _nameController.text.trim(),
      email: emailToSave,
      city: _cityController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      phone: firebasePhone, // always persist Firebase phone to DB
      imageBytes: _selectedImageBytes,
      imageExt: _selectedImageExt,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdentityVerificationPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userProviders.error ?? 'Failed to save profile')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /// Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        "Set Up Your Profile",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            /// Progress Bar Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FINAL STEP",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF05A4F),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "3 of 3",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF05A4F),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            /// Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Avatar Picker — perfectly centered
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE2E8F0),
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _selectedImageBytes != null
                                      ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                      : (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty
                                          ? Image.network(_existingAvatarUrl!, fit: BoxFit.cover)
                                          : const Icon(Icons.person, size: 50, color: Color(0xFF94A3B8))),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF05A4F),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Add a photo",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "So the community can recognize you",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Forms
                    _buildTextField(
                      label: "Full Name",
                      hintText: "Jane Doe",
                      icon: Icons.person,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    // Email field: locked when verified, editable when not
                    Builder(builder: (context) {
                      final isVerified = context.watch<UserProfileProvider>().isEmailVerified;
                      return _buildTextField(
                        label: "Email Address",
                        hintText: "jane@example.com",
                        icon: Icons.mail,
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        readOnly: isVerified, // lock when verified
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
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "City",
                      hintText: "New York, NY",
                      icon: Icons.location_on,
                      controller: _cityController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Age",
                      hintText: "25",
                      icon: Icons.cake,
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Mobile Number",
                      hintText: "+1 234 567 8900",
                      icon: Icons.phone,
                      controller: TextEditingController(text: AuthService().currentUser?.phoneNumber ?? ''),
                      readOnly: true,
                      keyboardType: TextInputType.phone,
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
                    
                    const SizedBox(height: 24),
                    
                    // Trust Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.verified_user, color: Color(0xFFF05A4F), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "This information helps us verify your identity and build trust within the Needin Express community.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 12,
                                color: Color(0xFF475569),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7F5).withValues(alpha: 0.95),
            border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A4F),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final name = _nameController.text.trim();
                      final city = _cityController.text.trim();
                      final ageStr = _ageController.text.trim();

                      if (name.isEmpty || city.isEmpty || ageStr.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Name, City, and Age are required")),
                        );
                        return;
                      }

                      final ageVal = int.tryParse(ageStr);
                      if (ageVal == null || ageVal < 18 || ageVal > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Age must be between 18 and 100")),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);
                      _doSaveProfile(context);
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Continue",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData icon,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? trailing,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: readOnly
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 16,
              color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              suffixIcon: trailing,
            ),
          ),
        ),
      ],
    );
  }
}
