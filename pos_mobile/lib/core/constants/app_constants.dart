import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Artisan POS';
  static const String defaultBusinessSlug = 'artisan-bistro';
  static const int defaultPort = 3000;

  /// Platforma göre otomatik sunucu adresini belirler
  /// Web -> localhost:3000
  /// Android Emulator -> 10.0.2.2:3000
  /// Windows / iOS Simulator / Desktop -> localhost:3000
  static String get serverBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://http://192.168.1.27:$defaultPort';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:$defaultPort';
    }
  }

  /// REST API v1 Base URL
  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  /// WebSocket Sunucu Adresi
  static String get socketUrl => serverBaseUrl;
}
