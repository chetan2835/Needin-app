import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_profile_provider.dart';
import '../../core/services/language_service.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _existingAvatarUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userProfileProv = Provider.of<UserProfileProvider>(context, listen: false);
    // If not loaded, load it. Usually we just load unconditionally to ensure freshness
    await userProfileProv.loadProfile();
    final profile = userProfileProv.profileData;
    final user = AuthService().currentUser;

    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name']?.toString() ?? '';
        _emailController.text = profile['email']?.toString() ?? '';
        _phoneController.text = profile['phone']?.toString() ??
            user?.phoneNumber ?? '';
        _dobController.text = profile['date_of_birth']?.toString() ?? '';
        _existingAvatarUrl = profile['profile_image_url']?.toString();
      });
    } else if (mounted) {
      // Fall back to Firebase phone
      _phoneController.text = user?.phoneNumber ?? '';
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

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty) {
      _showSnack('Full name is required', isError: true);
      return;
    }

    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email)) {
        _showSnack('Please enter a valid email', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);

    final userProviders = Provider.of<UserProfileProvider>(context, listen: false);

    final success = await userProviders.updateProfile(
      fullName: name,
      email: email.isNotEmpty ? email : null,
      phone: phone,
      dateOfBirth: dob.isNotEmpty ? dob : null,
      imageBytes: _selectedImageBytes,
      imageExt: _selectedImageExt,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        Navigator.pop(context, true); // Signal parent to refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        _showSnack('Failed to save. Please try again. ${userProviders.error}', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27F0D)))
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
                                            color: const Color(0xFFF27F0D),
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
                                      color: Color(0xFFF27F0D),
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
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  label: lang.t('email_address'),
                                  controller: _emailController,
                                  icon: Icons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 24),
                                _buildTextField(
                                  label: lang.t('phone_number'),
                                  controller: _phoneController,
                                  icon: Icons.call,
                                  keyboardType: TextInputType.phone,
                                  readOnly: true, // Phone number is from Firebase, not editable
                                ),
                                const SizedBox(height: 24),
                                // Date of birth
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.t('date_of_birth'),
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        DateTime initial = DateTime(1995, 1, 1);
                                        if (_dobController.text.isNotEmpty) {
                                          try {
                                            initial = DateTime.parse(_dobController.text);
                                          } catch (_) {}
                                        }
                                        DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: initial,
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                          builder: (context, child) => Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFFF27F0D),
                                              ),
                                            ),
                                            child: child!,
                                          ),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _dobController.text =
                                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, color: Color(0xFF94A3B8), size: 20),
                                            const SizedBox(width: 12),
                                            Text(
                                              _dobController.text.isNotEmpty
                                                  ? _dobController.text
                                                  : 'Select date',
                                              style: TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: _dobController.text.isNotEmpty
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
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
                            backgroundColor: const Color(0xFFF27F0D),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.5),
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
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
              suffixIcon: readOnly
                  ? const Icon(Icons.lock_outline, color: Color(0xFFCBD5E1), size: 18)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
