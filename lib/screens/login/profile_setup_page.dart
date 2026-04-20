import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_profile_provider.dart';
import 'service_selection_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _isLoading = false;
  
  bool _isEmailVerified = false;
  
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
        _dobController.text = profile['date_of_birth'] ?? '';
        _existingAvatarUrl = profile['profile_image_url'];
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF27F0D), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF0F172A), // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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

  void _verifyEmailFormat() {
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

    setState(() {
      _isEmailVerified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email format verified successfully!")),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5), // background-light
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
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), // slate-900
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
                          color: Color(0xFFF27F0D), // primary
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "3 of 3",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B), // slate-500
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0), // slate-200
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            /// Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    // Photo Uploader
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE2E8F0),
                                  border: Border.all(color: Colors.white, width: 4),
                                  image: _selectedImageBytes != null 
                                    ? DecorationImage(
                                        image: MemoryImage(_selectedImageBytes!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: _selectedImageBytes == null
                                    ? (_existingAvatarUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              _existingAvatarUrl!,
                                              key: UniqueKey(),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : ClipOval(
                                            child: Image.network(
                                              "https://lh3.googleusercontent.com/aida-public/AB6AXuCiXQboTHMVvOvz98Tf7qBQAr2J2hNXDZt7Gzl58x2heZPaksl5C7V9VMmAtemoSvmE5jwQLAznwK4epiBe6ZBztyJnhzoO4RXsOL0WkITkVebLKV_DscNhNgMSjdbvW-X_Oy56XmmqJTrmmeLTaKJz_zF-iLQM0MAdIW5Ma6xODDc6Of0lIYSi34q-YH4qx6pcSFdXY9RU3u53WMFk4vJ5Env9AKFchXe7tFcwCRzfl9A-I9j-5NQGVth9aLi9HDjAuHU3xcmSHg",
                                              key: UniqueKey(),
                                              fit: BoxFit.cover,
                                            ),
                                          ))
                                    : null,
                              ),
                              // Camera Badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF27F0D),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera,
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
                    const SizedBox(height: 32),
                    
                    // Forms
                    _buildTextField(
                      label: "Full Name",
                      hintText: "Jane Doe",
                      icon: Icons.person,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Email Address",
                      hintText: "jane@example.com",
                      icon: Icons.mail,
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                      trailing: _isEmailVerified
                          ? const Padding(
                              padding: EdgeInsets.only(right: 16.0),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            )
                          : TextButton(
                              onPressed: _verifyEmailFormat,
                              child: const Text("Verify", style: TextStyle(color: Color(0xFFF27F0D))),
                            ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "City",
                      hintText: "New York, NY",
                      icon: Icons.location_on,
                      controller: _cityController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Date of Birth",
                      hintText: "YYYY-MM-DD",
                      icon: Icons.calendar_today,
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Phone Number",
                      hintText: "+1 234 567 8900",
                      icon: Icons.phone,
                      controller: TextEditingController(text: AuthService().currentUser?.phoneNumber ?? ''),
                      readOnly: true,
                      keyboardType: TextInputType.phone,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Trust Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.verified_user, color: Color(0xFFF27F0D), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "This information helps us verify your identity and build trust within the Needin Express community.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 12,
                                color: Color(0xFF475569), // slate-600
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
                backgroundColor: const Color(0xFFF27F0D),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final name = _nameController.text.trim();
                      final email = _emailController.text.trim();
                      final city = _cityController.text.trim();
                      final dob = _dobController.text.trim();

                      if (name.isEmpty || email.isEmpty || city.isEmpty || dob.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All fields are required")),
                        );
                        return;
                      }

                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid email address")),
                        );
                        return;
                      }

                      setState(() {
                        _isLoading = true;
                      });

                      final userProviders = Provider.of<UserProfileProvider>(context, listen: false);

                      final phone = AuthService().currentUser?.phoneNumber;

                      final success = await userProviders.updateProfile(
                        fullName: name,
                        email: email,
                        city: city,
                        phone: phone,
                        dateOfBirth: dob,
                        imageBytes: _selectedImageBytes,
                        imageExt: _selectedImageExt,
                      );

                      if (!context.mounted) return;

                      setState(() {
                        _isLoading = false;
                      });

                      if (success) {
                        // Mark profile setup as complete locally
                        final uid = AuthService().currentUser?.uid ?? 'test_user_id';
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('profile_setup_complete_$uid', true);

                        if (!context.mounted) return;

                        Navigator.pushAndRemoveUntil(context,
                          MaterialPageRoute(
                            builder: (_) => const ServiceSelectionPage(),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to update profile. ${userProviders.error}")),
                        );
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Finish Setup",
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
    TextInputType? keyboardType,
    TextEditingController? controller,
    Widget? trailing,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              suffixIcon: trailing,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
