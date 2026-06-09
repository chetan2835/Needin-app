import 'package:flutter/foundation.dart';

class JourneyDraftProvider extends ChangeNotifier {
  Map<String, dynamic> _draftData = {};
  String? _draftId;

  Map<String, dynamic> get draftData => _draftData;
  String? get draftId => _draftId;

  void initialize({Map<String, dynamic>? initialData, String? id}) {
    _draftData = initialData != null ? Map<String, dynamic>.from(initialData) : {};
    _draftId = id;
    notifyListeners();
  }

  void updateData(Map<String, dynamic> newData) {
    _draftData.addAll(newData);
    notifyListeners();
  }

  void updateField(String key, dynamic value) {
    if (value == null) {
      _draftData.remove(key);
    } else {
      _draftData[key] = value;
    }
    notifyListeners();
  }

  void clear() {
    _draftData = {};
    _draftId = null;
    notifyListeners();
  }
}
