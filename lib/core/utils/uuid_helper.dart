import 'package:flutter/foundation.dart';

/// Centralized ID validation for the Needin booking pipeline.
///
/// IMPORTANT: This app uses Firebase Auth (text UIDs), NOT Supabase Auth.
/// - sender_id, traveler_id, driver_id → Firebase UIDs (alphanumeric TEXT)
/// - journey_id, parcel id           → Postgres UUIDs (uuid type)
///
/// Do NOT apply UUID regex validation to Firebase UIDs.
class UuidHelper {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Returns true if [input] matches standard UUID v4 format.
  static bool isValidUuid(String? input) {
    if (input == null) return false;
    return _uuidRegex.hasMatch(input.trim());
  }

  /// Trims whitespace, validates UUID format, and returns null if invalid.
  /// Use ONLY for actual Postgres UUID columns (journey_id, parcel id, etc).
  static String? safeUuidOrNull(String? input, {String? fieldName}) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (!_uuidRegex.hasMatch(trimmed)) {
      if (fieldName != null) {
        debugPrint('UUID_SAFETY: ⚠️ Invalid UUID format detected for $fieldName: "$input"');
      }
      return null;
    }
    return trimmed;
  }

  /// Validates UUID format and throws [FormatException] if invalid.
  /// Use ONLY for actual Postgres UUID columns (journey_id, parcel id, etc).
  static String requireValidUuid(String? input, {required String fieldName}) {
    final valid = safeUuidOrNull(input, fieldName: fieldName);
    if (valid == null) {
      throw FormatException('Invalid or missing UUID for $fieldName: "$input"');
    }
    return valid;
  }

  /// Validates a non-empty text ID (Firebase UID or any text-based ID).
  /// Use for sender_id, traveler_id, driver_id — these are Firebase UIDs (TEXT), not Postgres UUIDs.
  static String? safeTextIdOrNull(String? input, {String? fieldName}) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed == 'null') {
      if (fieldName != null) {
        debugPrint('ID_SAFETY: ⚠️ Empty or null text ID for $fieldName: "$input"');
      }
      return null;
    }
    return trimmed;
  }

  /// Validates a non-empty text ID and throws if invalid.
  /// Use for sender_id, traveler_id, driver_id — these are Firebase UIDs (TEXT), not Postgres UUIDs.
  static String requireNonEmptyId(String? input, {required String fieldName}) {
    final valid = safeTextIdOrNull(input, fieldName: fieldName);
    if (valid == null) {
      throw FormatException('Missing or empty ID for $fieldName: "$input"');
    }
    return valid;
  }
}
