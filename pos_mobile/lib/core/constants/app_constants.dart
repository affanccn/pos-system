import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Artisan POS';
  static const String defaultBusinessSlug = 'artisan-bistro';
  static const int defaultPort = 3000;

  /// ngrok tünel URL'si (farklı ağlardan erişim için)
  /// ngrok çalışmıyorsa yerel IP'ye düşer
  static const String? ngrokUrl =
      'https://bc78-2a02-4e0-2d0d-a1a-e191-f8ba-8908-b20a.ngrok-free.app';

  /// Yerel ağ IP adresi (aynı Wi-Fi'den erişim için)
  static const String localNetworkIp = '192.168.1.27';

  /// Platforma göre otomatik sunucu adresini belirler
  /// Web -> localhost:3000
  /// Android/iOS (ngrok varsa) -> ngrok URL
  /// Android/iOS (ngrok yoksa) -> yerel IP:3000
  static String get serverBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        // ngrok URL varsa onu kullan (farklı ağlardan erişim)
        if (ngrokUrl != null) return ngrokUrl!;
        return 'http://$localNetworkIp:$defaultPort';
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

