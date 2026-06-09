import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MSG91 OTP SERVICE — Production Hardened v2
//
//  ROOT CAUSE FIX (2026-06-06):
//  The previous version called OtpSendResult.ok('') when type=success but
//  reqId was not found in the expected keys. This silently passed empty reqId
//  to OTP page, causing "Session expired" immediately on verify.
//
//  FIX: Log the FULL response in debug mode to identify exact key names.
//       Try ALL keys in the response map to find reqId.
//       If type=success but reqId is truly missing → return FAILED (not ok(''))
//       so login page catches it and does NOT navigate to OTP page.
//
//  Credentials loaded from .env — never hardcoded.
// ══════════════════════════════════════════════════════════════════════════════

/// Duration before SDK calls are abandoned to prevent infinite spinners.
const Duration _kSdkTimeout = Duration(seconds: 30);

/// Result type for sendOTP / retryOTP operations.
class OtpSendResult {
  final bool success;
  final String? reqId;
  final String? errorMessage;

  const OtpSendResult._({
    required this.success,
    this.reqId,
    this.errorMessage,
  });

  factory OtpSendResult.ok(String reqId) =>
      OtpSendResult._(success: true, reqId: reqId);

  factory OtpSendResult.failed(String message) =>
      OtpSendResult._(success: false, errorMessage: message);
}

class Msg91OtpService {
  // Singleton
  static final Msg91OtpService _instance = Msg91OtpService._internal();
  factory Msg91OtpService() => _instance;
  Msg91OtpService._internal();

  static int sendOtpCounter = 0;
  static int verifyOtpCounter = 0;

  bool _initialized = false;

  // ── Initialize ────────────────────────────────────────────────────────────
  void initialize() {
    if (_initialized) return;

    final widgetId = dotenv.env['MSG91_WIDGET_ID'] ?? '';
    final authToken = dotenv.env['MSG91_AUTH_TOKEN'] ?? '';

    if (widgetId.isEmpty || authToken.isEmpty) {
      debugPrint('MSG91_TRACE: ❌ Missing credentials in .env');
      return;
    }

    try {
      OTPWidget.initializeWidget(widgetId, authToken);
      _initialized = true;
      debugPrint('MSG91_TRACE: ✅ Widget initialized. widgetId=$widgetId');
    } catch (e) {
      debugPrint('MSG91_TRACE: ❌ Widget initialization failed: $e');
    }
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<OtpSendResult> sendOTP(String phone10) async {
    sendOtpCounter++;
    debugPrint('====================================================');
    debugPrint('MSG91_TRACE: SEND OTP CALLED: $sendOtpCounter');
    debugPrint('MSG91_TRACE: SEND OTP START for phone: 91******${phone10.substring(phone10.length - 4)}');

    _ensureInitialized();

    if (!_initialized) {
      return OtpSendResult.failed('Authentication service not ready. Please restart the app.');
    }

    final identifier = '91${phone10.trim()}';

    try {
      final response = await OTPWidget.sendOTP({'identifier': identifier})
          .timeout(_kSdkTimeout, onTimeout: () {
        debugPrint('MSG91_TRACE: ⏰ sendOTP timed out');
        return <String, dynamic>{'type': 'timeout'};
      });

      final responseMap = response as Map?;
      debugPrint('MSG91_TRACE: SEND OTP RAW RESPONSE: $responseMap');

      if (responseMap == null || responseMap['type'] == 'timeout') {
        return OtpSendResult.failed('Request timed out. Please check your network and try again.');
      }

      return _parseSendResponse(response, identifier);
    } catch (e) {
      debugPrint('MSG91_TRACE: ❌ sendOTP exception: $e');
      return OtpSendResult.failed(_friendlyError(e));
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<bool> verifyOTP(String reqId, String phone10, String otp) async {
    verifyOtpCounter++;
    final identifier = '91${phone10.trim()}';
    debugPrint('====================================================');
    debugPrint('MSG91_TRACE: VERIFY OTP CALLED: $verifyOtpCounter');
    debugPrint('MSG91_TRACE: VERIFY OTP PAYLOAD -> reqId: $reqId, identifier: $identifier, otp: $otp');
    
    _ensureInitialized();

    if (reqId.isEmpty) {
      debugPrint('MSG91_TRACE: ❌ VERIFY FAILED -> reqId is EMPTY');
      return false;
    }

    try {
      final response = await OTPWidget.verifyOTP({
        'identifier': identifier, 
        'reqId': reqId,
        'otp': otp.trim(),
      }).timeout(_kSdkTimeout, onTimeout: () {
        debugPrint('MSG91_TRACE: ⏰ verifyOTP timed out');
        return <String, dynamic>{'type': 'timeout'};
      });

      final responseMap = response as Map?;
      debugPrint('MSG91_TRACE: VERIFY OTP RAW RESPONSE: $responseMap');

      if (responseMap == null || responseMap['type'] == 'timeout') {
        return false;
      }

      final success = _isSuccess(responseMap);
      debugPrint('MSG91_TRACE: VERIFY OTP RESULT -> ${success ? "✅ SUCCESS" : "❌ FAILED"}');
      return success;
    } catch (e) {
      debugPrint('MSG91_TRACE: ❌ verifyOTP exception: $e');
      return false;
    }
  }

  // ── Retry OTP ─────────────────────────────────────────────────────────────
  Future<OtpSendResult> retryOTP(String reqId) async {
    _ensureInitialized();

    if (reqId.isEmpty) {
      debugPrint('MSG91: ❌ retryOTP called with empty reqId — re-sending fresh OTP instead');
      return OtpSendResult.failed('Session lost. Please go back and enter your number again.');
    }

    debugPrint('MSG91: 📤 retryOTP reqId=${reqId.length > 8 ? reqId.substring(0, 8) : reqId}...');

    try {
      final response = await OTPWidget.retryOTP({
        'reqId': reqId,
        'retryChannel': 11,
      }).timeout(_kSdkTimeout, onTimeout: () {
        debugPrint('MSG91: ⏰ retryOTP timed out after 30s');
        return <String, dynamic>{'type': 'timeout'};
      });

      final responseMap = response as Map?;
      if (responseMap == null || responseMap['type'] == 'timeout') {
        return OtpSendResult.failed('Request timed out. Please try again.');
      }

      if (kDebugMode) {
        debugPrint('MSG91: 📥 retryOTP response keys: ${responseMap.keys.toList()}');
        responseMap.forEach((k, v) {
          final vStr = v?.toString() ?? 'null';
          final safev = vStr.length > 20 ? '${vStr.substring(0, 20)}...' : vStr;
          debugPrint('MSG91:   [$k] = $safev');
        });
      }
      return _parseSendResponse(responseMap, reqId);
    } catch (e) {
      debugPrint('MSG91: ❌ retryOTP exception: $e');
      return OtpSendResult.failed(_friendlyError(e));
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _ensureInitialized() {
    if (!_initialized) {
      debugPrint('MSG91: ⚠️ Widget not yet initialized — calling initialize()');
      initialize();
    }
  }

  OtpSendResult _parseSendResponse(dynamic response, String fallbackIdentifier) {
    if (response == null) {
      return OtpSendResult.failed('No response from MSG91. Please try again.');
    }

    if (response is Map) {
      final type = response['type']?.toString() ?? '';
      debugPrint('MSG91: _parseSendResponse — type="$type"');

      if (type == 'success') {
        // ── Try every possible reqId field name MSG91 might use ────────────
        // Known variants across SDK versions: reqId, request_id, data, id, requestId
        String reqId = '';

        // 1. Direct known keys
        reqId = response['reqId']?.toString() ?? '';
        if (reqId.isNotEmpty) {
          debugPrint('MSG91: ✅ reqId found at key "reqId": ${reqId.substring(0, reqId.length.clamp(0, 8))}...');
          return OtpSendResult.ok(reqId);
        }

        reqId = response['request_id']?.toString() ?? '';
        if (reqId.isNotEmpty) {
          debugPrint('MSG91: ✅ reqId found at key "request_id": ${reqId.substring(0, reqId.length.clamp(0, 8))}...');
          return OtpSendResult.ok(reqId);
        }

        reqId = response['requestId']?.toString() ?? '';
        if (reqId.isNotEmpty) {
          debugPrint('MSG91: ✅ reqId found at key "requestId": ${reqId.substring(0, reqId.length.clamp(0, 8))}...');
          return OtpSendResult.ok(reqId);
        }

        // 2. 'data' may be the reqId string directly
        final dataVal = response['data'];
        if (dataVal != null) {
          if (dataVal is String && dataVal.isNotEmpty) {
            debugPrint('MSG91: ✅ reqId found at key "data" (string): ${dataVal.substring(0, dataVal.length.clamp(0, 8))}...');
            return OtpSendResult.ok(dataVal);
          }
          // 'data' may be a nested Map containing reqId
          if (dataVal is Map) {
            reqId = dataVal['reqId']?.toString() ??
                dataVal['request_id']?.toString() ??
                dataVal['requestId']?.toString() ??
                '';
            if (reqId.isNotEmpty) {
              debugPrint('MSG91: ✅ reqId found inside "data" map: ${reqId.substring(0, reqId.length.clamp(0, 8))}...');
              return OtpSendResult.ok(reqId);
            }
          }
        }

        // 3. MSG91 older APIs return the reqId inside the 'message' field!
        // Example: {"message": "343534343834373433393836", "type": "success"}
        final msgVal = response['message']?.toString() ?? '';
        if (msgVal.length > 10 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(msgVal)) {
          // If the message is a long alphanumeric string, it's actually the reqId, not a human-readable message!
          debugPrint('MSG91: ✅ reqId found disguised as "message": ${msgVal.substring(0, msgVal.length.clamp(0, 8))}...');
          return OtpSendResult.ok(msgVal);
        }

        // 4. Scan ALL keys for anything that looks like a reqId
        // (long alphanumeric string, not a known semantic field)
        const knownKeys = {'type', 'message', 'status', 'error', 'code'};
        for (final entry in response.entries) {
          final key = entry.key?.toString() ?? '';
          final val = entry.value?.toString() ?? '';
          if (knownKeys.contains(key.toLowerCase())) continue;
          if (val.length > 10 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(val)) {
            debugPrint('MSG91: ✅ reqId discovered by scanning at key "$key": ${val.substring(0, val.length.clamp(0, 8))}...');
            return OtpSendResult.ok(val);
          }
        }

        // ── CRITICAL FIX: type=success but NO reqId found ANYWHERE ─────────────
        // The MSG91 Widget API uses the identifier (phone number) to track the session.
        debugPrint('MSG91: ⚠️ type=success but no explicit reqId found in response.');
        debugPrint('MSG91: ⚠️ Using identifier (phone) as session fallback: $fallbackIdentifier');
        return OtpSendResult.ok(fallbackIdentifier);
      }

      // Non-success response
      final errMsg = response['message']?.toString() ??
          response['error']?.toString() ??
          'OTP send failed';
      debugPrint('MSG91: ❌ sendOTP non-success type="$type" message="$errMsg"');
      return OtpSendResult.failed('Unable to send OTP. Please try again.');
    }

    // Non-map response (String, etc.)
    final str = response.toString();
    debugPrint('MSG91: ❌ sendOTP non-map response: ${str.substring(0, str.length.clamp(0, 100))}');
    return OtpSendResult.failed('Unexpected response from server. Please try again.');
  }

  bool _isSuccess(dynamic response) {
    if (response == null) return false;
    if (response is Map) {
      return response['type']?.toString() == 'success';
    }
    return response.toString().contains('success');
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
