import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class AppProvider with ChangeNotifier {
  bool isLoading = false;

  Map<String, dynamic>? userProfile;

  Future<void> loadDashboardData() async {
    isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseService();
      final uid = AuthService().currentUser?.uid;
      
      if (uid != null) {
        userProfile = await supabase.getUserProfile(uid);
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
