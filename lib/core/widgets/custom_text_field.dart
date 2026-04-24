import 'package:flutter/material.dart';
import '../constants/ui_utils.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int? maxLength;
  final String? Function(String?)? validator;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.prefixText,
    this.maxLength,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      style: const TextStyle(
        fontFamily: "Plus Jakarta Sans",
        fontWeight: FontWeight.w500,
        color: UIUtils.textMain,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: UIUtils.textSecondary),
        prefixIcon: Icon(icon, color: UIUtils.primary),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: UIUtils.textMain,
          fontWeight: FontWeight.bold,
        ),
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
          borderSide: const BorderSide(color: UIUtils.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: UIUtils.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: UIUtils.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: validator,
    );
  }
}
