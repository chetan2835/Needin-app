import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class PaymentService {
  late Razorpay _razorpay;

  // Ideally, load these from your backend or environment variables
  final String _keyId = "rzp_test_YourTestKeyId"; // REPLACE with actual Key ID
  
  // Callbacks
  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onError;
  Function(ExternalWalletResponse)? onWallet;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void openCheckout({
    required int amountInPaise,
    required String contactNumber,
    required String email,
    required String description,
  }) {
    var options = {
      'key': _keyId,
      'amount': amountInPaise,
      'name': 'Needin Express',
      'description': description,
      'prefill': {
        'contact': contactNumber,
        'email': email,
      },
      'theme': {
        'color': '#F27F0D' // Primary color matching UI
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: \$e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Success: \${response.paymentId}");
    if (onSuccess != null) {
      onSuccess!(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Error: \${response.code} - \${response.message}");
    if (onError != null) {
      onError!(response);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet Selected: \${response.walletName}");
    if (onWallet != null) {
      onWallet!(response);
    }
  }

  void dispose() {
    _razorpay.clear(); // Removes all listeners
  }
}
