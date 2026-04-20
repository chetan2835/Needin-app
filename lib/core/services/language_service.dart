import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight i18n service with SharedPreferences persistence.
/// Supports 10+ Indian + international languages.
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLocale = 'en';
  String get currentLocale => _currentLocale;

  /// All supported languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'ur', 'name': 'Urdu', 'native': 'اردو'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
  ];

  /// Translation strings for all supported languages
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'profile': 'Profile',
      'personal_info': 'Personal Information',
      'identity_verification': 'Identity Verification',
      'payment_methods': 'Payment Methods',
      'notification_settings': 'Notification Settings',
      'language': 'Language',
      'help_support': 'Help & Support',
      'logout': 'Logout',
      'account': 'ACCOUNT',
      'settings': 'SETTINGS',
      'journeys': 'Journeys',
      'parcels': 'Parcels',
      'earnings': 'Earnings',
      'verified': 'VERIFIED',
      'pending': 'PENDING',
      'save_changes': 'Save Changes',
      'full_name': 'Full Name',
      'email_address': 'Email Address',
      'phone_number': 'Phone Number',
      'date_of_birth': 'Date of Birth',
      'personal_details': 'Personal Details',
      'change_photo': 'Change Photo',
      'linked_accounts': 'Linked Accounts',
      'connected': 'Connected',
      'not_connected': 'Not Connected',
      'logout_confirm': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'select_language': 'Select Language',
      'home': 'Home',
      'orders': 'Orders',
      'wallet': 'Wallet',
      'welcome_back': 'Welcome back,',
      'hello': 'Hello',
      'notifications': 'Notifications',
      'push_notifications': 'Push Notifications',
      'order_updates': 'Order Updates',
      'promotional': 'Promotional',
      'security_alerts': 'Security Alerts',
      'email_notifications': 'Email Notifications',
      'sms_notifications': 'SMS Notifications',
      'help_center': 'Help Center',
      'faq': 'Frequently Asked Questions',
      'contact_us': 'Contact Us',
      'report_issue': 'Report an Issue',
      'terms': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',
      'about': 'About Needin Express',
    },
    'hi': {
      'profile': 'प्रोफ़ाइल',
      'personal_info': 'व्यक्तिगत जानकारी',
      'identity_verification': 'पहचान सत्यापन',
      'payment_methods': 'भुगतान के तरीके',
      'notification_settings': 'सूचना सेटिंग्स',
      'language': 'भाषा',
      'help_support': 'सहायता और समर्थन',
      'logout': 'लॉगआउट',
      'account': 'खाता',
      'settings': 'सेटिंग्स',
      'journeys': 'यात्राएँ',
      'parcels': 'पार्सल',
      'earnings': 'कमाई',
      'verified': 'सत्यापित',
      'pending': 'लंबित',
      'save_changes': 'बदलाव सहेजें',
      'full_name': 'पूरा नाम',
      'email_address': 'ईमेल पता',
      'phone_number': 'फ़ोन नंबर',
      'date_of_birth': 'जन्म तिथि',
      'personal_details': 'व्यक्तिगत विवरण',
      'change_photo': 'फ़ोटो बदलें',
      'linked_accounts': 'जुड़े हुए खाते',
      'connected': 'जुड़ा हुआ',
      'not_connected': 'जुड़ा नहीं',
      'logout_confirm': 'क्या आप लॉगआउट करना चाहते हैं?',
      'cancel': 'रद्द करें',
      'confirm': 'पुष्टि करें',
      'select_language': 'भाषा चुनें',
      'home': 'होम',
      'orders': 'ऑर्डर',
      'wallet': 'वॉलेट',
      'welcome_back': 'वापसी पर स्वागत,',
      'hello': 'नमस्ते',
      'notifications': 'सूचनाएँ',
      'push_notifications': 'पुश सूचनाएँ',
      'order_updates': 'ऑर्डर अपडेट',
      'promotional': 'प्रचार',
      'security_alerts': 'सुरक्षा अलर्ट',
      'email_notifications': 'ईमेल सूचनाएँ',
      'sms_notifications': 'SMS सूचनाएँ',
      'help_center': 'सहायता केंद्र',
      'faq': 'अक्सर पूछे जाने वाले प्रश्न',
      'contact_us': 'संपर्क करें',
      'report_issue': 'समस्या रिपोर्ट करें',
      'terms': 'सेवा की शर्तें',
      'privacy_policy': 'गोपनीयता नीति',
      'about': 'Needin Express के बारे में',
    },
    'pa': {
      'profile': 'ਪ੍ਰੋਫਾਈਲ',
      'personal_info': 'ਨਿੱਜੀ ਜਾਣਕਾਰੀ',
      'identity_verification': 'ਪਛਾਣ ਤਸਦੀਕ',
      'payment_methods': 'ਭੁਗਤਾਨ ਦੇ ਤਰੀਕੇ',
      'notification_settings': 'ਸੂਚਨਾ ਸੈਟਿੰਗ',
      'language': 'ਭਾਸ਼ਾ',
      'help_support': 'ਮਦਦ ਅਤੇ ਸਹਾਇਤਾ',
      'logout': 'ਲੌਗਆਉਟ',
      'account': 'ਖਾਤਾ',
      'settings': 'ਸੈਟਿੰਗ',
      'journeys': 'ਯਾਤਰਾਵਾਂ',
      'parcels': 'ਪਾਰਸਲ',
      'earnings': 'ਕਮਾਈ',
      'logout_confirm': 'ਕੀ ਤੁਸੀਂ ਲੌਗਆਉਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
      'cancel': 'ਰੱਦ ਕਰੋ',
      'confirm': 'ਪੁਸ਼ਟੀ ਕਰੋ',
      'select_language': 'ਭਾਸ਼ਾ ਚੁਣੋ',
    },
    'bn': {
      'profile': 'প্রোফাইল',
      'personal_info': 'ব্যক্তিগত তথ্য',
      'identity_verification': 'পরিচয় যাচাই',
      'payment_methods': 'পেমেন্ট পদ্ধতি',
      'logout': 'লগআউট',
      'account': 'অ্যাকাউন্ট',
      'settings': 'সেটিংস',
      'journeys': 'যাত্রা',
      'parcels': 'পার্সেল',
      'earnings': 'আয়',
      'logout_confirm': 'আপনি কি লগআউট করতে চান?',
      'cancel': 'বাতিল',
      'confirm': 'নিশ্চিত করুন',
      'select_language': 'ভাষা নির্বাচন করুন',
    },
    'ta': {
      'profile': 'சுயவிவரம்',
      'personal_info': 'தனிப்பட்ட தகவல்',
      'logout': 'வெளியேறு',
      'account': 'கணக்கு',
      'settings': 'அமைப்புகள்',
      'journeys': 'பயணங்கள்',
      'parcels': 'பார்சல்',
      'earnings': 'வருவாய்',
      'logout_confirm': 'நீங்கள் வெளியேற விரும்புகிறீர்களா?',
      'cancel': 'ரத்து',
      'confirm': 'உறுதிப்படுத்து',
      'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
    },
    'te': {
      'profile': 'ప్రొఫైల్',
      'personal_info': 'వ్యక్తిగత సమాచారం',
      'logout': 'లాగ్అవుట్',
      'select_language': 'భాషను ఎంచుకోండి',
    },
    'mr': {
      'profile': 'प्रोफाइल',
      'personal_info': 'वैयक्तिक माहिती',
      'logout': 'लॉगआउट',
      'select_language': 'भाषा निवडा',
    },
  };

  /// Initialize from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_language') ?? 'en';
    notifyListeners();
  }

  /// Set and persist language
  Future<void> setLanguage(String code) async {
    _currentLocale = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    notifyListeners();
  }

  /// Get translated string — falls back to English if missing
  String t(String key) {
    return _translations[_currentLocale]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  /// Get display name for current language
  String get currentLanguageName {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == _currentLocale,
      orElse: () => supportedLanguages.first,
    );
    return lang['name']!;
  }

  /// Get native name for current language
  String get currentLanguageNative {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == _currentLocale,
      orElse: () => supportedLanguages.first,
    );
    return lang['native']!;
  }
}
