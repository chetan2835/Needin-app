import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production DigiLocker integration service.
/// Communicates with Supabase Edge Functions for real OAuth2 flow.
/// Follows the existing singleton pattern used by SupabaseService & AuthService.
class DigiLockerService {
  // Singleton instance
  static final DigiLockerService _instance = DigiLockerService._internal();
  factory DigiLockerService() => _instance;
  DigiLockerService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Initiates DigiLocker verification via Edge Function.
  /// Returns the OAuth2 authorization URL to open in system browser.
  /// Throws [DigiLockerException] on failure with user-friendly message.
  Future<String> initiateVerification() async {
    try {
      final response = await _client.functions.invoke(
        'digilocker-initiate',
        method: HttpMethod.post,
      );

      if (response.status == 401) {
        throw const DigiLockerException(
          'Please log in again.',
          code: 'auth_required',
        );
      }

      if (response.status == 409) {
        throw const DigiLockerException(
          'already_verified',
          code: 'already_verified',
        );
      }

      if (response.status != 200) {
        final body = response.data;
        String errorMsg = 'Unable to connect. Please try again.';
        if (body is Map<String, dynamic> && body['error'] != null) {
          if (body['error'] == 'already_verified') {
            throw const DigiLockerException(
              'already_verified',
              code: 'already_verified',
            );
          }
          errorMsg = body['error'].toString();
        }
        throw DigiLockerException(errorMsg);
      }

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const DigiLockerException('Unable to connect. Please try again.');
      }

      final url = body['url'] as String?;
      if (url == null || url.isEmpty) {
        throw const DigiLockerException('Unable to connect. Please try again.');
      }

      return url;
    } on DigiLockerException {
      rethrow;
    } on SocketException catch (_) {
      throw const DigiLockerException(
        'Service temporarily unavailable. Try again shortly.',
        code: 'network',
      );
    } on TimeoutException catch (_) {
      throw const DigiLockerException(
        'Request timed out. Please try again.',
        code: 'timeout',
      );
    } on FunctionException catch (e) {
      debugPrint('DigiLocker FunctionException: ${e.status} ${e.details}');
      if (e.status == 401) {
        throw const DigiLockerException(
          'Please log in again.',
          code: 'auth_required',
        );
      }
      // Edge Function not deployed or unreachable
      throw const DigiLockerException(
        'Service temporarily unavailable. Try again shortly.',
        code: 'function_error',
      );
    } catch (e) {
      debugPrint('DigiLocker initiate error: $e');
      throw const DigiLockerException(
        'Service temporarily unavailable. Try again shortly.',
        code: 'unknown',
      );
    }
  }

  /// Fetches current verification status from backend.
  /// Returns graceful default on any failure (never throws).
  Future<DigiLockerStatus> getStatus() async {
    try {
      final response = await _client.functions.invoke(
        'digilocker-status',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        return const DigiLockerStatus(
          isVerified: false,
          status: 'not_started',
          isServiceAvailable: false,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const DigiLockerStatus(
          isVerified: false,
          status: 'not_started',
          isServiceAvailable: false,
        );
      }

      return DigiLockerStatus.fromJson(data).copyWith(isServiceAvailable: true);
    } catch (e) {
      debugPrint('DigiLocker status error: $e');
      // Return unverified status on error (graceful degradation)
      return const DigiLockerStatus(
        isVerified: false,
        status: 'not_started',
        isServiceAvailable: false,
      );
    }
  }
}

/// Immutable status model for DigiLocker verification state.
class DigiLockerStatus {
  final bool isVerified;
  final String? verifiedAt;
  final String? name;
  final String? digilockerId;
  final String status; // 'not_started' | 'pending' | 'verified' | 'failed'
  final String? failureReason;
  final bool isServiceAvailable;

  const DigiLockerStatus({
    required this.isVerified,
    this.verifiedAt,
    this.name,
    this.digilockerId,
    required this.status,
    this.failureReason,
    this.isServiceAvailable = true,
  });

  factory DigiLockerStatus.fromJson(Map<String, dynamic> json) {
    return DigiLockerStatus(
      isVerified: json['is_verified'] as bool? ?? false,
      verifiedAt: json['verified_at'] as String?,
      name: json['name'] as String?,
      digilockerId: json['digilocker_id'] as String?,
      status: json['status'] as String? ?? 'not_started',
      failureReason: json['failure_reason'] as String?,
    );
  }

  DigiLockerStatus copyWith({bool? isServiceAvailable}) {
    return DigiLockerStatus(
      isVerified: isVerified,
      verifiedAt: verifiedAt,
      name: name,
      digilockerId: digilockerId,
      status: status,
      failureReason: failureReason,
      isServiceAvailable: isServiceAvailable ?? this.isServiceAvailable,
    );
  }
}

/// Custom exception for DigiLocker operations.
class DigiLockerException implements Exception {
  final String message;
  final String? code;
  const DigiLockerException(this.message, {this.code});
  @override
  String toString() => message;
}
