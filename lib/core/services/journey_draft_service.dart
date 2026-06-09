import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class JourneyDraftService {
  static final JourneyDraftService _instance = JourneyDraftService._internal();
  factory JourneyDraftService() => _instance;
  JourneyDraftService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Save or update a journey draft
  Future<bool> saveDraft({
    String? existingDraftId,
    required int currentStep,
    required double completionPercentage,
    required Map<String, dynamic> draftData,
    String? origin,
    String? destination,
  }) async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return false;

      final data = {
        'driver_id': uid,
        'status': 'draft',
        'current_step': currentStep,
        'completion_percentage': completionPercentage,
        'draft_data': draftData,
        'last_saved_at': DateTime.now().toIso8601String(),
        'origin': origin ?? 'Incomplete Route',
        'destination': destination ?? 'Incomplete Route',
        'departure_time': draftData['departure_time'] ?? DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'capacity_kg': draftData['capacity_kg'] ?? 0,
        'price_per_kg': draftData['price_per_kg'] ?? 0,
      };

      if (existingDraftId != null) {
        await _client.from('journeys').update(data).eq('id', existingDraftId);
      } else {
        await _client.from('journeys').insert(data);
      }
      return true;
    } catch (e) {
      debugPrint("Error saving draft: $e");
      return false;
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(String draftId) async {
    try {
      await _client.from('journeys').delete().eq('id', draftId);
      return true;
    } catch (e) {
      debugPrint("Error deleting draft: $e");
      return false;
    }
  }
}
