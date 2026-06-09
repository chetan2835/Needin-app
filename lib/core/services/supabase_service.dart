import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'auth_service.dart';
import '../models/parcel_model.dart';
import '../models/journey_model.dart';
import '../utils/uuid_helper.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  SupabaseClient get _client => Supabase.instance.client;

  // ══════════════════════════════════════════════════════════════
  //  LOCAL CACHE (SharedPreferences)
  // ══════════════════════════════════════════════════════════════

  Future<void> _saveProfileLocally(String userId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'profile_$userId';
    if (data['full_name'] != null) await prefs.setString('${prefix}_full_name', data['full_name'].toString());
    if (data['email'] != null) await prefs.setString('${prefix}_email', data['email'].toString());
    if (data['city'] != null) await prefs.setString('${prefix}_city', data['city'].toString());
    if (data['phone'] != null) await prefs.setString('${prefix}_phone', data['phone'].toString());
    if (data['is_profile_complete'] != null) await prefs.setBool('${prefix}_is_profile_complete', data['is_profile_complete'] == true);
    if (data['date_of_birth'] != null) await prefs.setString('${prefix}_date_of_birth', data['date_of_birth'].toString());
    if (data['age'] != null) await prefs.setInt('${prefix}_age', data['age'] is int ? data['age'] : int.tryParse(data['age'].toString()) ?? 0);
    // Support both column names for image URL
    final imageUrl = data['profile_image_url'] ?? data['avatar_url'];
    if (imageUrl != null) await prefs.setString('${prefix}_profile_image_url', imageUrl.toString());
    // CRITICAL: persist email verification state so it survives offline/cache fallback
    if (data['email_verified'] != null) await prefs.setBool('${prefix}_email_verified', data['email_verified'] == true);
    if (data['email_verified_at'] != null) await prefs.setString('${prefix}_email_verified_at', data['email_verified_at'].toString());
    debugPrint("LOCAL_CACHE: Profile saved locally for $userId (email_verified=${data['email_verified']})");
  }

  Future<Map<String, dynamic>?> _loadProfileLocally(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'profile_$userId';
    final name = prefs.getString('${prefix}_full_name');
    if (name == null) return null;
    return {
      'full_name': name,
      'email': prefs.getString('${prefix}_email') ?? '',
      'city': prefs.getString('${prefix}_city') ?? '',
      'profile_image_url': prefs.getString('${prefix}_profile_image_url'),
      'phone': prefs.getString('${prefix}_phone') ?? '',
      'is_profile_complete': prefs.getBool('${prefix}_is_profile_complete') ?? false,
      'date_of_birth': prefs.getString('${prefix}_date_of_birth'),
      'age': prefs.getInt('${prefix}_age'),
      // CRITICAL: restore email_verified from cache so offline loads don't revert to false
      'email_verified': prefs.getBool('${prefix}_email_verified') ?? false,
      'email_verified_at': prefs.getString('${prefix}_email_verified_at'),
    };
  }

  // ══════════════════════════════════════════════════════════════
  //  EMAIL VERIFICATION LOCAL PERSISTENCE
  // ══════════════════════════════════════════════════════════════

  /// Persist email_verified=true directly to local SharedPreferences.
  /// Called immediately after OTP verification to guarantee that a cold
  /// restart still shows the verified badge even before the backend fetch.
  Future<void> persistEmailVerifiedLocally({
    required String userId,
    required String email,
    required String verifiedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'profile_$userId';
    await prefs.setString('${prefix}_email', email);
    await prefs.setBool('${prefix}_email_verified', true);
    await prefs.setString('${prefix}_email_verified_at', verifiedAt);
    debugPrint('LOCAL_CACHE: ✅ email_verified=true written for $userId ($email)');
  }

  // ══════════════════════════════════════════════════════════════
  //  PROFILE FETCH
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // ── ATTEMPT 1: Via get_profile_by_firebase_uid RPC ────────────────────
    // This RPC looks up by the firebase_uid TEXT column, completely bypassing
    // the profiles.id UUID type issue that caused silent failures before.
    try {
      final rows = await _client
          .rpc('get_profile_by_firebase_uid', params: {'p_firebase_uid': userId});
      if (rows != null && rows is List && rows.isNotEmpty) {
        final Map<String, dynamic> response = Map<String, dynamic>.from(rows.first as Map);
        if (response.containsKey('avatar_url') && !response.containsKey('profile_image_url')) {
          response['profile_image_url'] = response['avatar_url'];
        }
        await _saveProfileLocally(userId, response);
        debugPrint('DB_FETCH: ✅ Profile by firebase_uid=$userId (email_verified=${response['email_verified']})');
        return response;
      }
    } catch (e) {
      debugPrint('DB_FETCH: ⚠️ get_profile_by_firebase_uid failed: $e');
    }

    // ── ATTEMPT 2: Via get_profile_by_phone RPC ───────────────────────────
    // After reinstall, the Firebase phone number is always known from Auth.
    // Critical fallback for returning users who verified email previously.
    try {
      final phone = AuthService().currentUser?.phoneNumber;
      if (phone != null && phone.isNotEmpty) {
        final rows = await _client
            .rpc('get_profile_by_phone', params: {'p_phone': phone});
        if (rows != null && rows is List && rows.isNotEmpty) {
          final Map<String, dynamic> response = Map<String, dynamic>.from(rows.first as Map);
          if (response.containsKey('avatar_url') && !response.containsKey('profile_image_url')) {
            response['profile_image_url'] = response['avatar_url'];
          }
          await _saveProfileLocally(userId, response);
          // Also link this profile's firebase_uid for future lookups (fire-and-forget)
          _client.rpc('upsert_profile_by_firebase_uid', params: {
            'p_firebase_uid': userId,
            'p_phone': phone,
          }).catchError((_) {});
          debugPrint('DB_FETCH: ✅ Profile by phone=$phone (email_verified=${response['email_verified']})');
          return response;
        }
      }
    } catch (e) {
      debugPrint('DB_FETCH: ⚠️ get_profile_by_phone failed: $e');
    }

    // ── ATTEMPT 3: Local cache (offline fallback) ─────────────────────────
    debugPrint('DB_FETCH: Using local cache for $userId');
    return _loadProfileLocally(userId);
  }


  // ══════════════════════════════════════════════════════════════
  //  PROFILE UPSERT (NEVER CRASHES)
  // ══════════════════════════════════════════════════════════════

  Future<bool> upsertUserProfile({
    required String userId,
    String? fullName,
    String? email,
    String? city,
    String? profileImageUrl,
    String? phone,
    int? age,
  }) async {
    final data = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (city != null) 'city': city,
      if (phone != null) 'phone': phone,
      if (age != null) 'age': age,
    };
    if (profileImageUrl != null) {
      data['profile_image_url'] = profileImageUrl;
      data['avatar_url'] = profileImageUrl;
    }

    // 1. ALWAYS save locally first
    await _saveProfileLocally(userId, data);

    // 2. Persist to Supabase via the firebase_uid RPC
    // This RPC uses firebase_uid TEXT column (not the UUID id column),
    // completely bypassing the silent cast failure that was losing all data.
    try {
      final isComplete = (fullName?.trim().isNotEmpty ?? false) &&
                         (city?.trim().isNotEmpty ?? false);
      final result = await _client.rpc(
        'upsert_profile_by_firebase_uid',
        params: {
          'p_firebase_uid': userId,
          if (phone != null)          'p_phone': phone,
          if (fullName != null)       'p_full_name': fullName,
          if (email != null)          'p_email': email,
          if (city != null)           'p_city': city,
          if (age != null)            'p_age': age,
          if (profileImageUrl != null) 'p_profile_image_url': profileImageUrl,
          if (isComplete)             'p_is_complete': true,
        },
      );
      if (result != null && result['success'] == true) {
        debugPrint('DB_WRITE: ✅ Profile saved via upsert_profile_by_firebase_uid (${result['action']})');
      } else {
        debugPrint('DB_WRITE: ⚠️ RPC returned: $result');
      }
    } catch (e) {
      debugPrint('DB_WRITE: ⚠️ upsert_profile_by_firebase_uid failed: $e — saved locally only');
    }
    return true; // Always return true — local save is guaranteed
  }

  // ══════════════════════════════════════════════════════════════
  //  IMAGE UPLOAD
  // ══════════════════════════════════════════════════════════════

  Future<String?> uploadProfilePicture(String userId, Uint8List imageBytes, String extension) async {
    try {
      final cleanExt = extension.replaceAll('.', '');

      // ── Compress image if > 500KB ──
      Uint8List processedBytes = imageBytes;
      if (imageBytes.length > 500 * 1024) {
        debugPrint("IMG_COMPRESS: Original ${imageBytes.length} bytes, compressing...");
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            imageBytes,
            minWidth: 1024,
            minHeight: 1024,
            quality: 80,
            format: cleanExt == 'png' ? CompressFormat.png : CompressFormat.jpeg,
          );
          processedBytes = Uint8List.fromList(compressed);
          debugPrint("IMG_COMPRESS: Compressed to ${processedBytes.length} bytes (${(processedBytes.length * 100 / imageBytes.length).toStringAsFixed(0)}%)");
        } catch (e) {
          debugPrint("IMG_COMPRESS: Compression failed ($e), uploading original");
        }
      }

      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      debugPrint("IMG_UPLOAD: Uploading $fileName (${processedBytes.length} bytes)...");

      await _client.storage.from('avatars').uploadBinary(
        fileName,
        processedBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(fileName);
      debugPrint("IMG_UPLOAD: ✅ Success! URL: $publicUrl");
      return publicUrl;
    } catch (e) {
      debugPrint("IMG_UPLOAD: ❌ Failed: $e");
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  RETENTION CLEANUP
  // ══════════════════════════════════════════════════════════════

  /// Calls the backend retention cleanup function.
  /// Deletes delivered/cancelled parcels and soft-deletes expired journeys
  /// that are older than 30 days. Safe to call on every page load — it's
  /// a no-op if nothing has expired.
  Future<void> runRetentionCleanup() async {
    try {
      final result = await _client.rpc('run_retention_cleanup');
      debugPrint('RETENTION: ✅ Cleanup done: $result');
    } catch (e) {
      // Non-critical — UI filtering still enforces the window client-side
      debugPrint('RETENTION: ⚠️ Cleanup RPC failed (non-critical): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  ETD BOOKING CUTOFF
  // ══════════════════════════════════════════════════════════════

  /// Returns the current server time from the database.
  /// Falls back to local device time if the RPC fails.
  /// Use this to compare against departure_time without trusting device clock.
  Future<DateTime> getServerTime() async {
    try {
      final result = await _client.rpc('get_server_time');
      if (result != null) {
        final parsed = DateTime.tryParse(result.toString());
        if (parsed != null) {
          debugPrint('SERVER_TIME: ✅ DB time = $parsed');
          return parsed.toLocal();
        }
      }
    } catch (e) {
      debugPrint('SERVER_TIME: ⚠️ RPC failed, using device time: $e');
    }
    // Fallback: device local time
    return DateTime.now();
  }

  /// Checks whether a journey is still bookable based on the server's DB clock.
  ///
  /// Returns a map with:
  ///   - `canBook` (bool): whether booking is currently allowed
  ///   - `reason` (String): one of 'ok', 'etd_passed', 'journey_not_found',
  ///     'journey_deleted', 'journey_not_active'
  ///   - `message` (String): human-readable explanation
  ///
  /// Falls back to local departure_time comparison if the RPC fails.
  Future<Map<String, dynamic>> checkJourneyBookable(
    String journeyId, {
    String? localDepartureTimeIso,
  }) async {
    // Try server-side RPC first (uses DB NOW() — immune to device clock drift)
    try {
      final safeId = UuidHelper.safeUuidOrNull(journeyId, fieldName: 'journeyId');
      if (safeId == null || safeId.isEmpty) {
        return {
          'canBook': false,
          'reason': 'invalid_id',
          'message': 'Invalid journey ID.',
        };
      }

      final result = await _client.rpc(
        'can_book_journey',
        params: {'p_journey_id': safeId},
      );

      if (result != null) {
        final data = Map<String, dynamic>.from(result as Map);
        final canBook = data['can_book'] == true;
        final reason = data['reason']?.toString() ?? 'unknown';
        final message = data['message']?.toString() ?? '';
        debugPrint('ETD_CHECK: ✅ RPC result — canBook=$canBook reason=$reason');
        return {'canBook': canBook, 'reason': reason, 'message': message};
      }
    } catch (e) {
      debugPrint('ETD_CHECK: ⚠️ RPC failed, falling back to local check: $e');
    }

    // Fallback: local departure_time comparison
    if (localDepartureTimeIso != null && localDepartureTimeIso.isNotEmpty) {
      final depTime = DateTime.tryParse(localDepartureTimeIso);
      if (depTime != null) {
        final now = DateTime.now();
        final depLocal = depTime.toLocal();
        if (now.isAfter(depLocal) || now.isAtSameMomentAs(depLocal)) {
          debugPrint('ETD_CHECK: ⚠️ Local fallback — ETD passed. dep=$depLocal now=$now');
          return {
            'canBook': false,
            'reason': 'etd_passed',
            'message': 'Booking for this journey is closed because the departure time has already started.',
          };
        }
      }
    }

    // If we can't determine — allow (backend trigger will be the final gate)
    debugPrint('ETD_CHECK: ⚠️ Could not determine ETD status — allowing (backend trigger is final gate)');
    return {'canBook': true, 'reason': 'unknown', 'message': ''};
  }

  // ══════════════════════════════════════════════════════════════
  //  USER STATS (Retention-Aware)
  // ══════════════════════════════════════════════════════════════

  /// Returns journey and parcel counts filtered by the 30-day retention window.
  /// Uses backend RPCs (get_user_journey_count / get_user_parcel_count) for
  /// accuracy. Falls back to client-side filtered counts if RPCs are unavailable.
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    const retentionWindow = Duration(days: 30);
    final cutoff = DateTime.now().toUtc().subtract(retentionWindow);

    try {
      // ── Tier 1: Use retention-aware backend RPCs ──────────────────
      int journeyCount = 0;
      int parcelCount = 0;

      try {
        final jResult = await _client.rpc(
          'get_user_journey_count',
          params: {'p_user_id': userId},
        );
        journeyCount = (jResult as int?) ?? 0;
        debugPrint('STATS: ✅ Journey count (RPC): $journeyCount');
      } catch (e) {
        debugPrint('STATS: ⚠️ Journey count RPC failed ($e), using client-side filter');
        // ── Tier 2: Client-side retention filter ──────────────────────
        try {
          final jRes = await _client
              .from('journeys')
              .select('id, status, departure_time, is_deleted, retention_expires_at')
              .eq('driver_id', userId);
          final allJourneys = List<Map<String, dynamic>>.from(jRes as List);
          journeyCount = allJourneys.where((j) {
            final isDeleted = j['is_deleted'] == true;
            if (isDeleted) return false;
            final status = (j['status'] ?? '').toString().toLowerCase();
            // Active statuses always count
            if (['active', 'live', 'in_progress', 'draft'].contains(status)) return true;
            // Terminal statuses: check retention window
            final retExpiresStr = j['retention_expires_at']?.toString();
            final depStr = j['departure_time']?.toString();
            if (retExpiresStr != null) {
              final retExpires = DateTime.tryParse(retExpiresStr)?.toUtc();
              if (retExpires != null && retExpires.isBefore(DateTime.now().toUtc())) return false;
            } else if (depStr != null) {
              final dep = DateTime.tryParse(depStr)?.toUtc();
              if (dep != null && dep.isBefore(cutoff)) return false;
            }
            return true;
          }).length;
        } catch (_) {}
      }

      // ── Tier 2: Client-side retention filter (Forced) ─────────────────
      // We explicitly bypass the 'get_user_parcel_count' RPC here because the 
      // current live backend RPC contains a bug where it fails to exclude cancelled 
      // bookings, resulting in an inflated count. This client-side logic is 100% accurate.
      try {
        final pRes = await _client
            .from('parcels')
            .select('id, status, created_at, retention_expires_at, cancelled_at')
            .eq('sender_id', userId);
        final allParcels = List<Map<String, dynamic>>.from(pRes as List);
        parcelCount = allParcels.where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();

          // Cancelled and disputed bookings NEVER count — regardless of retention window.
          if (status == 'cancelled' || status == 'disputed') return false;

          // Active (non-terminal) records always count
          if (!['delivered', 'completed'].contains(status)) return true;
          
          // Terminal (delivered/completed): only count within 30-day retention
          final retExpiresStr = p['retention_expires_at']?.toString();
          if (retExpiresStr != null) {
            final retExpires = DateTime.tryParse(retExpiresStr)?.toUtc();
            if (retExpires != null && retExpires.isBefore(DateTime.now().toUtc())) return false;
          } else {
            // Fallback: use created_at when retention_expires_at is missing
            final createdStr = p['created_at']?.toString();
            if (createdStr != null) {
              final created = DateTime.tryParse(createdStr)?.toUtc();
              if (created != null && created.isBefore(cutoff)) return false;
            }
          }
          return true;
        }).length;
        debugPrint('STATS: ✅ Parcel count (Client-side strict): $parcelCount');
      } catch (e) {
        debugPrint('STATS: ❌ Client-side parcel count failed: $e');
      }

      return {
        'journeys': journeyCount,
        'parcels': parcelCount,
        'earnings': 0.0,
      };
    } catch (e) {
      debugPrint('STATS: ❌ Error fetching user stats: $e');
      return {'journeys': 0, 'parcels': 0, 'earnings': 0.0};
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PARCELS
  // ══════════════════════════════════════════════════════════════

  Future<List<Parcel>> getRecentParcels() async {
    try {
      final String? uid = AuthService().currentUser?.uid;
      if (uid == null) return [];

      final response = await _client
          .from('parcels')
          .select()
          .eq('sender_id', uid)
          .order('created_at', ascending: false)
          .limit(10);

      return (response as List).map((item) => Parcel.fromJson(item)).toList();
    } catch (e) {
      debugPrint("Error fetching recent parcels: $e");
      return [];
    }
  }

  /// Create a new parcel and return its ID
  Future<String?> createParcel(Map<String, dynamic> parcelData) async {
    try {
      final response = await _client
          .from('parcels')
          .insert(parcelData)
          .select('id')
          .single();
      return response['id']?.toString();
    } catch (e) {
      debugPrint("Error creating parcel: $e");
      return null;
    }
  }

  /// Update parcel status
  Future<bool> updateParcelStatus(String parcelId, String status) async {
    try {
      await _client
          .from('parcels')
          .update({'status': status})
          .eq('id', parcelId);
      return true;
    } catch (e) {
      debugPrint("Error updating parcel status: $e");
      return false;
    }
  }

  /// Cancel a booking (parcel) with a reason and notify the traveler
  Future<bool> cancelBooking({
    required String parcelId,
    required String reason,
    required String canceledByUid,
    String? travelerId,
  }) async {
    try {
      await _client.from('parcels').update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        'cancelled_by': canceledByUid,
      }).eq('id', parcelId);

      // Attempt to notify the traveler if travelerId is known (non-blocking)
      if (travelerId != null && travelerId.isNotEmpty) {
        _notifyTraveler(
          travelerId: travelerId,
          title: 'Booking Cancelled',
          message: 'A sender has cancelled their parcel booking request.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint("Error cancelling booking: $e\n$stackTrace");
      return false;
    }
  }

  /// Hard delete a booking (parcel) completely from the database
  Future<bool> deleteBooking({
    required String parcelId,
    required String senderId,
  }) async {
    try {
      await _client.from('parcels').delete().eq('id', parcelId).eq('sender_id', senderId);
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error deleting booking: $e\n$stackTrace");
      return false;
    }
  }

  /// Classify parcel by dimensions (calls edge function or local logic)
  Future<Map<String, dynamic>> classifyParcel({
    required double length,
    required double width,
    required double height,
    required double weight,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'classify-parcel',
        body: {
          'length': length,
          'width': width,
          'height': height,
          'weight': weight,
          if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        },
      );
      return response.data as Map<String, dynamic>? ?? {'category': 'medium'};
    } catch (e) {
      debugPrint("Error classifying parcel: $e");
      // Fallback: local classification
      final volume = length * width * height;
      String category;
      if (volume < 500 && weight < 2) {
        category = 'small';
      } else if (volume < 5000 && weight < 10) {
        category = 'medium';
      } else {
        category = 'large';
      }
      return {'category': category};
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  TRANSACTIONS
  // ══════════════════════════════════════════════════════════════

  Future<bool> createTransaction(String parcelId, double amount, String status) async {
    try {
      await _client.from('transactions').insert({
        'parcel_id': parcelId,
        'amount': amount,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("Error creating transaction: $e");
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  JOURNEYS
  // ══════════════════════════════════════════════════════════════

  Future<List<Journey>> getPopularJourneys() async {
    try {
      final response = await _client
          .from('journeys')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      return (response as List).map((item) => Journey.fromJson(item)).toList();
    } catch (e) {
      debugPrint("Error fetching popular journeys: $e");
      return [];
    }
  }

  Future<bool> saveJourney({
    required String userId,
    required String fromLocation,
    required String toLocation,
    String? date,
    String? mode,
    double? availableWeight,
    String? notes,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final data = {
        'driver_id': userId,
        'origin': fromLocation,
        'destination': toLocation,
        'travel_mode': mode ?? 'road',
        'capacity_kg': availableWeight ?? 10,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        if (date != null) 'departure_time': date,
        if (extraData != null) ...extraData,
      };

      await _client.from('journeys').insert(data);
      return true;
    } catch (e) {
      debugPrint("Error saving journey: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserJourneys(String userId) async {
    try {
      // Primary query: filter by driver_id + is_deleted=false (preferred)
      try {
        final response = await _client
            .from('journeys')
            .select()
            .eq('driver_id', userId)
            .eq('is_deleted', false)
            .order('created_at', ascending: false);
        debugPrint('JOURNEYS: ✅ Fetched ${(response as List).length} journeys for $userId');
        return List<Map<String, dynamic>>.from(response);
      } catch (e1) {
        debugPrint('JOURNEYS: is_deleted filter failed ($e1), trying without it...');
        // Fallback: query without is_deleted filter
        final response = await _client
            .from('journeys')
            .select()
            .eq('driver_id', userId)
            .order('created_at', ascending: false);
        debugPrint('JOURNEYS: ✅ Fallback fetched ${(response as List).length} journeys for $userId');
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('JOURNEYS: ❌ Error fetching journeys: $e');
      return [];
    }
  }

  /// Insert a journey and return the created record (confirms DB write before showing success)
  /// Throws on failure so the UI can display the actual error.
  Future<Map<String, dynamic>?> createJourneyAndReturn(Map<String, dynamic> data) async {
    try {
      debugPrint('JOURNEY_CREATE: 🚀 Inserting journey payload keys: ${data.keys.toList()}');
      debugPrint('JOURNEY_CREATE: driver_id=${data['driver_id']}, origin=${data['origin']}, dest=${data['destination']}');
      final response = await _client
          .from('journeys')
          .insert(data)
          .select()
          .single();
      debugPrint('JOURNEY_CREATE: ✅ Journey created with id=${response['id']}');
      return response;
    } catch (e, stackTrace) {
      debugPrint('JOURNEY_CREATE: ❌ Insert failed: $e');
      debugPrint('JOURNEY_CREATE: ❌ Stack: $stackTrace');
      // Rethrow so caller can display the actual error
      rethrow;
    }
  }

  /// Extract detailed error info from PostgrestException for debugging.
  void _logPostgrestError(String label, Object error) {
    if (error is PostgrestException) {
      debugPrint('$label PostgrestException:');
      debugPrint('  code   : ${error.code}');
      debugPrint('  message: ${error.message}');
      debugPrint('  details: ${error.details}');
      debugPrint('  hint   : ${error.hint}');
    } else {
      debugPrint('$label ${error.runtimeType}: $error');
    }
  }

  /// Attempt to reload PostgREST schema cache.
  /// This fixes "invalid input syntax for type uuid" when migrations
  /// changed column types but PostgREST still has old types cached.
  Future<bool> _reloadSchemaCache() async {
    try {
      // Method 1: Direct NOTIFY via RPC (works if the function exists)
      try {
        await _client.rpc('reload_pgrst_schema');
        debugPrint('SCHEMA_RELOAD: ✅ RPC reload_pgrst_schema succeeded');
        return true;
      } catch (_) {
        debugPrint('SCHEMA_RELOAD: ⚠️ RPC not available, trying raw SQL...');
      }

      // Method 2: Try a benign schema operation that forces cache refresh
      // A simple SELECT on information_schema can sometimes trigger a refresh
      try {
        await _client
            .from('parcels')
            .select('id')
            .limit(0);
        debugPrint('SCHEMA_RELOAD: ✅ Schema probe SELECT succeeded');
      } catch (_) {
        debugPrint('SCHEMA_RELOAD: ⚠️ Schema probe failed');
      }

      return false;
    } catch (e) {
      debugPrint('SCHEMA_RELOAD: ❌ Failed: $e');
      return false;
    }
  }

  /// Create a booking (parcel linked to a journey + traveler)
  ///
  /// Uses a 3-tier insert strategy to handle all possible DB schema states:
  ///   Tier 1: Full payload (all columns including migration-added ones)
  ///   Tier 2: Core payload (only columns from init.sql + traveler_id)
  ///   Tier 3: Bare minimum (only init.sql original columns)
  ///
  /// If all tiers fail with 22P02 (stale PostgREST schema cache),
  /// attempts a schema cache reload and retries.
  Future<String?> createBooking({
    required String senderId,
    required String journeyId,
    required String travelerId,
    required String parcelSize,
    required double price,
    required String origin,
    required String destination,
    String? travelMode,
    String? description,
    String? departureTimeIso,
  }) async {
    try {
      // ── Input validation ──────────────────────────────────────────
      final safeSenderId = UuidHelper.requireNonEmptyId(senderId, fieldName: 'senderId');
      final safeJourneyId = UuidHelper.requireValidUuid(journeyId, fieldName: 'journeyId');
      final safeTravelerId = UuidHelper.requireNonEmptyId(travelerId, fieldName: 'travelerId');

      // ── CRITICAL: ETD Booking Cutoff Check (server-side) ─────────
      // Re-validate at the moment of booking — do NOT trust stale UI state.
      // This prevents race conditions where the user opened the screen before
      // ETD but tries to confirm after ETD has passed.
      debugPrint('BOOKING_CREATE: ⏰ Checking ETD for journey $safeJourneyId...');
      final etdCheck = await checkJourneyBookable(
        safeJourneyId,
        localDepartureTimeIso: departureTimeIso,
      );
      if (etdCheck['canBook'] != true) {
        final reason = etdCheck['reason']?.toString() ?? 'etd_passed';
        final msg = etdCheck['message']?.toString() ??
            'Booking for this journey is closed because the departure time has already started.';
        debugPrint('BOOKING_CREATE: ⛔ ETD check blocked booking — reason=$reason');
        throw Exception('ETD_PASSED: $msg');
      }
      debugPrint('BOOKING_CREATE: ✅ ETD check passed — booking allowed');

      // Compute travel-mode-aware weight
      final isFlightBooking = (travelMode ?? '').toLowerCase() == 'flight';
      final double weightKg;
      if (isFlightBooking) {
        // Flight: Small=1kg, Medium=3kg, Large=5kg
        weightKg = parcelSize == 'small' ? 1.0 : parcelSize == 'medium' ? 3.0 : 5.0;
      } else {
        // Non-flight: Small=2kg, Medium=5kg, Large=25kg
        weightKg = parcelSize == 'small' ? 2.0 : parcelSize == 'medium' ? 5.0 : 25.0;
      }
      final categoryName = parcelSize[0].toUpperCase() + parcelSize.substring(1);
      final pickupPin = ((1000 + DateTime.now().millisecond * 9) % 9000 + 1000).toString().substring(0, 4);
      final dropoffPin = ((1000 + DateTime.now().microsecond % 9000) % 9000 + 1000).toString().substring(0, 4);
      final parcelTitle = '$categoryName Parcel';

      debugPrint('BOOKING_CREATE: 🚀 sender=$safeSenderId journey=$safeJourneyId traveler=$safeTravelerId size=$parcelSize price=$price');

      // ── Duplicate booking prevention ──────────────────────────────
      try {
        final existing = await _client
            .from('parcels')
            .select('id, status')
            .eq('sender_id', safeSenderId)
            .eq('journey_id', safeJourneyId);
        final existingList = List<Map<String, dynamic>>.from(existing as List);
        final hasActiveDuplicate = existingList.any((p) {
          final s = (p['status'] ?? '').toString().toLowerCase();
          return s != 'cancelled' && s != 'delivered' && s != 'completed';
        });
        if (hasActiveDuplicate) {
          debugPrint('BOOKING_CREATE: ⛔ Duplicate blocked');
          throw Exception('You have already booked this traveler. Check your My Bookings for details.');
        }
      } catch (e) {
        if (e.toString().contains('already booked')) rethrow;
        if (e.toString().contains('ETD_PASSED')) rethrow;
        debugPrint('BOOKING_CREATE: ⚠️ Duplicate check failed (proceeding): $e');
      }

      // ── Try insert with retry-after-schema-reload strategy ────────
      Map<String, dynamic>? response;
      bool schemaReloadAttempted = false;

      for (int attempt = 0; attempt < 2; attempt++) {
        if (attempt == 1) {
          debugPrint('BOOKING_CREATE: 🔄 RETRY after schema cache reload (attempt 2)');
        }

        // ── TIER 1: Full payload (migrated schema) ──────────────────
        final tier1Payload = {
          'sender_id': safeSenderId,
          'journey_id': safeJourneyId,
          'traveler_id': safeTravelerId,
          'title': parcelTitle,
          'description': description ?? '',
          'weight_kg': weightKg,
          'parcel_size': parcelSize,
          'parcel_category': categoryName,
          'origin': origin,
          'destination': destination,
          'pickup_pin': pickupPin,
          'dropoff_pin': dropoffPin,
          'status': 'pending',
          'booking_status': 'pending',
          'price': price,
          if (travelMode != null && travelMode.isNotEmpty) 'travel_mode': travelMode,
        };

        debugPrint('BOOKING_CREATE: Tier 1 — full payload (attempt ${attempt + 1})');

        try {
          response = await _client
              .from('parcels')
              .insert(tier1Payload)
              .select('id')
              .single();
          debugPrint('BOOKING_CREATE: ✅ Tier 1 succeeded');
          break; // SUCCESS
        } catch (e1) {
          _logPostgrestError('BOOKING_CREATE Tier1:', e1);

          // ── TIER 2: Core payload ──────────────────────────────────
          final tier2Payload = {
            'sender_id': safeSenderId,
            'journey_id': safeJourneyId,
            'traveler_id': safeTravelerId,
            'title': parcelTitle,
            'description': description ?? '',
            'weight_kg': weightKg,
            'parcel_size': parcelSize,
            'parcel_category': categoryName,
            'origin': origin,
            'destination': destination,
            'pickup_pin': pickupPin,
            'dropoff_pin': dropoffPin,
            'status': 'pending',
            'price': price,
            if (travelMode != null && travelMode.isNotEmpty) 'travel_mode': travelMode,
          };

          debugPrint('BOOKING_CREATE: Tier 2 — core payload (attempt ${attempt + 1})');

          try {
            response = await _client
                .from('parcels')
                .insert(tier2Payload)
                .select('id')
                .single();
            debugPrint('BOOKING_CREATE: ✅ Tier 2 succeeded');
            break; // SUCCESS
          } catch (e2) {
            _logPostgrestError('BOOKING_CREATE Tier2:', e2);

            // ── TIER 3: Bare minimum ────────────────────────────────
            final tier3Payload = {
              'sender_id': safeSenderId,
              'journey_id': safeJourneyId,
              'title': parcelTitle,
              'description': description ?? '',
              'weight_kg': weightKg,
              'parcel_size': parcelSize,
              'origin': origin,
              'destination': destination,
              'pickup_pin': pickupPin,
              'dropoff_pin': dropoffPin,
              'status': 'pending',
              'price': price,
            };

            debugPrint('BOOKING_CREATE: Tier 3 — bare minimum (attempt ${attempt + 1})');

            try {
              response = await _client
                  .from('parcels')
                  .insert(tier3Payload)
                  .select('id')
                  .single();
              debugPrint('BOOKING_CREATE: ✅ Tier 3 succeeded');
              break; // SUCCESS
            } catch (e3) {
              _logPostgrestError('BOOKING_CREATE Tier3:', e3);

              final err3Str = e3.toString().toLowerCase();

              // If 22P02 and we haven't tried schema reload yet, try it
              if (!schemaReloadAttempted &&
                  (err3Str.contains('22p02') || err3Str.contains('invalid input syntax'))) {
                debugPrint('BOOKING_CREATE: 🔄 All tiers failed with 22P02 — attempting schema cache reload...');
                schemaReloadAttempted = true;
                await _reloadSchemaCache();
                // Wait a moment for cache to refresh
                await Future.delayed(const Duration(milliseconds: 1500));
                continue; // Retry all tiers
              }

              // If we already retried, or it's a different error, give up
              debugPrint('BOOKING_CREATE: ╔═══════════════════════════════════════════════════╗');
              debugPrint('BOOKING_CREATE: ║  ALL INSERT TIERS FAILED                         ║');
              debugPrint('BOOKING_CREATE: ║  sender_id=$safeSenderId');
              debugPrint('BOOKING_CREATE: ║  journey_id=$safeJourneyId');
              debugPrint('BOOKING_CREATE: ║  traveler_id=$safeTravelerId');
              debugPrint('BOOKING_CREATE: ║  price=$price, size=$parcelSize');
              debugPrint('BOOKING_CREATE: ╚═══════════════════════════════════════════════════╝');

              // Throw with actionable message
              if (err3Str.contains('22p02') || err3Str.contains('invalid input syntax')) {
                throw Exception(
                  'SCHEMA_CACHE_STALE: The database schema cache needs refreshing. '
                  'Please go to Supabase Dashboard → SQL Editor and run: '
                  'NOTIFY pgrst, \'reload schema\';'
                );
              }
              rethrow;
            }
          }
        }
      }

      if (response == null) {
        throw Exception('Booking insert returned no response after all attempts.');
      }

      final bookingId = response['id']?.toString();
      debugPrint('BOOKING_CREATE: ✅ Booking created id=$bookingId');

      // Attempt to backfill traveler_id and parcel metadata if needed (non-blocking)
      if (bookingId != null) {
        final backfillData = <String, dynamic>{
          'traveler_id': safeTravelerId,
          'parcel_size': parcelSize,
          'parcel_category': categoryName,
        };
        if (travelMode != null && travelMode.isNotEmpty) {
          backfillData['travel_mode'] = travelMode;
        }
        _client.from('parcels').update(backfillData).eq('id', bookingId).then((_) {
          debugPrint('BOOKING_CREATE: 🔧 Backfilled traveler_id + parcel metadata on booking $bookingId');
        }).catchError((e) {
          debugPrint('BOOKING_CREATE: ⚠️ Backfill failed (non-critical): $e');
        });
      }

      // Notify traveler (non-blocking)
      final notifMsg = 'A sender wants to ship a $categoryName Parcel on your journey from $origin to $destination.';
      _notifyTraveler(
        travelerId: travelerId,
        title: 'New Parcel Request',
        message: notifMsg,
      );

      return bookingId;
    } catch (e, stackTrace) {
      if (e.toString().contains('idx_unique_active_booking_per_journey') || e.toString().contains('duplicate key value')) {
        throw Exception('You have already booked this traveler. Check your My Bookings for details.');
      }
      debugPrint('BOOKING_CREATE: ❌ Final failure: ${e.runtimeType}: $e');
      debugPrint('BOOKING_CREATE: ❌ Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> _notifyTraveler({
    required String travelerId,
    required String title,
    required String message,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': travelerId,
        'title': title,
        'message': message,
        'type': 'booking',
      });
      debugPrint('NOTIFY: ✅ Notification sent to traveler $travelerId');
    } catch (e) {
      debugPrint('NOTIFY: ⚠️ Failed to notify traveler: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchMatches({
    required String fromLocation,
    required String toLocation,
    String? type,
  }) async {
    try {
      final table = type == 'journey' ? 'journeys' : 'parcels';

      // First, try to match by route (case-insensitive partial match)
      if (fromLocation.isNotEmpty && toLocation.isNotEmpty) {
        try {
          final routeMatched = await _client
              .from(table)
              .select()
              .eq('status', 'active')
              .ilike('origin', '%${fromLocation.split(',').first.trim()}%')
              .ilike('destination', '%${toLocation.split(',').first.trim()}%')
              .order('created_at', ascending: false)
              .limit(20);

          if ((routeMatched as List).isNotEmpty) {
            debugPrint("SEARCH: Found ${routeMatched.length} route-matched results");
            return List<Map<String, dynamic>>.from(routeMatched);
          }
        } catch (e) {
          debugPrint("SEARCH: Route filter failed ($e), falling back to all active");
        }
      }

      // Fallback: return all active journeys
      final response = await _client
          .from(table)
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error searching matches: $e");
      return [];
    }
  }

  Future<bool> saveParcelRequest({
    required String userId,
    required String fromLocation,
    required String toLocation,
    String? parcelSize,
    double? weight,
    String? description,
    String? recipientName,
    String? recipientPhone,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      // Generate 4-digit PINs for pickup and dropoff verification
      final pickupPin = (1000 + DateTime.now().millisecond * 9).toString().substring(0, 4);
      final dropoffPin = (1000 + DateTime.now().microsecond % 9000).toString().substring(0, 4);
      
      final data = {
        'sender_id': userId,
        'title': description ?? 'Parcel',
        'description': description ?? '',
        'origin': fromLocation,
        'destination': toLocation,
        'parcel_size': parcelSize ?? 'medium',
        'weight_kg': weight ?? 1,
        'pickup_pin': pickupPin,
        'dropoff_pin': dropoffPin,
        'price': 0, // Price will be calculated separately
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        if (extraData != null) ...extraData,
      };

      await _client.from('parcels').insert(data);
      return true;
    } catch (e) {
      debugPrint("Error saving parcel request: $e");
      return false;
    }
  }
}
