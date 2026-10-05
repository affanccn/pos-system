import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../../main.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  io.Socket? get rawSocket => _socket;

  void initSocket(String token) {
    if (_socket != null && _socket!.connected) return;

    final socketUrl = AppConstants.socketUrl;
    debugPrint('🔌 [Socket] Bağlantı başlatılıyor ($socketUrl)... Token uzunluğu: ${token.length}');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('⚡ [Socket] Sunucuya başarıyla bağlandı!');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 [Socket] Bağlantı koptu.');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('❌ [Socket Hata]: $err');
      notifyListeners();
    });

    _socket!.on('notification', (data) {
      debugPrint('🔔 [Bildirim]: $data');
      if (data != null && data['title'] != null) {
        _showNotification(data);
      }
    });
  }

  void _showNotification(Map<String, dynamic> data) {
    final title = data['title'] as String;
    final body = data['body'] as String?;
    final type = data['type'] as String?;

    Color bgColor = const Color(0xFF38BDF8);
    IconData icon = Icons.notifications;

    if (type == 'CRITICAL_STOCK') {
      bgColor = const Color(0xFFEF4444);
      icon = Icons.warning_amber_rounded;
    } else if (type == 'WAITER_CALL') {
      bgColor = const Color(0xFFF59E0B);
      icon = Icons.room_service;
    } else if (type == 'BILL_READY') {
      bgColor = const Color(0xFF10B981);
      icon = Icons.receipt_long;
    } else if (type == 'PRODUCT_READY' || type == 'ORDER_READY') {
      bgColor = const Color(0xFF10B981);
      icon = Icons.restaurant;
    }

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (body != null) Text(body, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }
}

final socketServiceProvider = ChangeNotifierProvider<SocketService>((ref) {
  return SocketService();
});