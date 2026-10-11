// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/services/app_settings.dart
// Centralized Dynamic Settings Service with Resilient Fallback (Singleton)
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/platform_settings_model.dart';
import 'api_client.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  static AppSettings get instance => _instance;

  AppSettings._internal();

  PlatformSettingsModel _settings = PlatformSettingsModel.defaultSettings();

  PlatformSettingsModel get current => _settings;
  String get appName => _settings.appName;
  String get supportEmail => _settings.supportEmail;
  List<String> get whatsappNumbers => List.unmodifiable(_settings.whatsappNumbers);
  String? get primaryColorHex => _settings.primaryColorHex;
  String? get accentColorHex => _settings.accentColorHex;

  /// Loads public settings from the server.
  /// If it fails (offline, error), falls back gracefully to default settings.
  Future<void> loadSettings({ApiClient? client}) async {
    try {
      final fetched = await ApiClient.getPublicSettings();
      if (fetched != null) {
        _settings = fetched;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppSettings] Could not fetch public settings, using fallback: $e');
    }
  }

  /// Updates settings locally (e.g. after successful admin save)
  void updateLocally(PlatformSettingsModel newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  /// Reset to default fallback (useful for tests)
  void resetToDefaults() {
    _settings = PlatformSettingsModel.defaultSettings();
    notifyListeners();
  }
}
