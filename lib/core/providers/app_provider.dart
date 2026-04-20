import 'package:flutter/material.dart';
import '../models/journey_model.dart';
import '../models/parcel_model.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class AppProvider with ChangeNotifier {
  List<Journey> popularJourneys = [];
  List<Parcel> recentParcels = [];
  bool isLoading = false;

  Map<String, dynamic>? userProfile;

  Future<void> loadDashboardData() async {
    isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseService();
      final uid = AuthService().currentUser?.uid;
      
      // Load concurrency
      final results = await Future.wait([
        supabase.getPopularJourneys(),
        supabase.getRecentParcels(),
        if (uid != null) supabase.getUserProfile(uid) else Future.value(null),
      ]);

      popularJourneys = results[0] as List<Journey>;
      recentParcels = results[1] as List<Parcel>;
      if (results.length > 2) {
        userProfile = results[2] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
