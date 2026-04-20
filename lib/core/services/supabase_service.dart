import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'auth_service.dart';
import '../models/parcel_model.dart';
import '../models/journey_model.dart';

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
    if (data['date_of_birth'] != null) await prefs.setString('${prefix}_date_of_birth', data['date_of_birth'].toString());
    // Support both column names for image URL
    final imageUrl = data['profile_image_url'] ?? data['avatar_url'];
    if (imageUrl != null) await prefs.setString('${prefix}_profile_image_url', imageUrl.toString());
    debugPrint("LOCAL_CACHE: Profile saved locally for $userId");
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
      'date_of_birth': prefs.getString('${prefix}_date_of_birth'),
    };
  }

  // ══════════════════════════════════════════════════════════════
  //  PROFILE FETCH
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Use 'id' column because actual schema has no 'user_id'
      var response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        // Normalize: ensure profile_image_url key exists
        if (response.containsKey('avatar_url') && !response.containsKey('profile_image_url')) {
          response['profile_image_url'] = response['avatar_url'];
        }
        await _saveProfileLocally(userId, response);
        debugPrint("DB_FETCH: ✅ Profile loaded from Supabase for $userId");
        return response;
      }
    } catch (e) {
      debugPrint("DB_FETCH: ⚠️ Supabase profile fetch failed: $e");
    }

    // Fall back to local cache
    debugPrint("DB_FETCH: Using local cache for $userId");
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
    String? dateOfBirth,
  }) async {
    final data = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email,
      if (city != null) 'city': city,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    };

    // Handle image URL — send to both possible column names
    if (profileImageUrl != null) {
      data['profile_image_url'] = profileImageUrl;
      data['avatar_url'] = profileImageUrl;
    }

    // 1. ALWAYS save locally first (guaranteed to work)
    await _saveProfileLocally(userId, data);

    // 2. Try Supabase (best-effort, never throws)
    try {
      final updates = <String, dynamic>{
        'id': userId,
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _client.from('profiles').upsert(updates, onConflict: 'id');
        debugPrint("DB_WRITE: ✅ Profile synced via id");
        return true;
      } catch (e1) {
        debugPrint("DB_WRITE: id upsert failed ($e1). Saved locally only.");
        return true;
      }
    } catch (e) {
      debugPrint("DB_WRITE: ⚠️ Unexpected error: $e. Saved locally.");
      return true;
    }
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
  //  USER STATS
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      int journeyCount = 0;
      try {
        final journeyResponse = await _client
            .from('journeys')
            .select()
            .eq('driver_id', userId);
        journeyCount = (journeyResponse as List).length;
      } catch (_) {}

      int parcelCount = 0;
      try {
        final parcelResponse = await _client
            .from('parcels')
            .select()
            .eq('sender_id', userId);
        parcelCount = (parcelResponse as List).length;
      } catch (_) {}

      return {
        'journeys': journeyCount,
        'parcels': parcelCount,
        'earnings': 0.0,
      };
    } catch (e) {
      debugPrint("Error fetching user stats: $e");
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
      final response = await _client
          .from('journeys')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching journeys: $e");
      return [];
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
