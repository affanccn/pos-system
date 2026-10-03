import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Artisan POS';
  static const String defaultBusinessSlug = 'artisan-bistro';
  static const int defaultPort = 3000;

  /// Render Production URL
  static const String productionUrl = 'https://pos-system-nd0u.onrender.com';

  /// Platforma göre otomatik sunucu adresini belirler
  static String get serverBaseUrl {
    // Mobil veya masaüstü için her zaman production URL'yi kullan
    if (!kIsWeb) {
      return productionUrl;
    }
    // Web için geliştirme ortamında localhost çalışabilir
    return kReleaseMode ? productionUrl : 'http://localhost:$defaultPort';
  }

  /// REST API v1 Base URL
  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  /// WebSocket Sunucu Adresi
  static String get socketUrl => serverBaseUrl;
}
