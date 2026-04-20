import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  ConfirmationResult? _confirmationResult; // Used specifically for Web

  /// Initiate Phone Number Verification using Firebase
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) verificationFailed,
  }) async {
    try {
      if (kIsWeb) {
        // Web requires signInWithPhoneNumber for automatic reCAPTCHA handling
        _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        _verificationId = _confirmationResult!.verificationId;
        codeSent(_verificationId ?? "web-verification-id");
      } else {
        // Android / iOS handling
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              await _auth.signInWithCredential(credential);
            } catch (e) {
              verificationFailed(e.toString());
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            verificationFailed(e.message ?? 'Verification failed');
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            codeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      verificationFailed(e.toString());
    }
  }

  /// Verify the OTP code entered by the user
  Future<UserCredential?> verifyOTP(String otp) async {
    try {
      if (kIsWeb) {
        if (_confirmationResult == null) throw Exception("Confirmation result missing for Web.");
        return await _confirmationResult!.confirm(otp);
      } else {
        if (_verificationId == null) throw Exception("Verification ID is missing. Request OTP first.");
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("OTP Verification failed: \$e");
      }
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;
}
