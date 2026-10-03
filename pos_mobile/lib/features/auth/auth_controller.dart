import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class UserState {
  final bool isAuthenticated;
  final String? role;
  final String? name;
  final List<String> permissions;
  final String? errorMessage;
  final bool isLoading;

  UserState({
    this.isAuthenticated = false,
    this.role,
    this.name,
    this.permissions = const [],
    this.errorMessage,
    this.isLoading = false,
  });

  bool hasPermission(String perm) {
    if (role?.toUpperCase() == 'OWNER') return true;
    return permissions.contains(perm);
  }

  bool hasAnyPermission(List<String> perms) {
    if (role?.toUpperCase() == 'OWNER') return true;
    return perms.any((p) => permissions.contains(p));
  }

  bool hasRole(String targetRole) =>
      role?.toUpperCase() == targetRole.toUpperCase();

  bool get isOwner => hasRole('OWNER');

  bool get isManager => hasRole('MANAGER') || isOwner;

  bool get isWaiter => hasRole('WAITER');

  bool get isKitchen => hasRole('KITCHEN');

  UserState copyWith({
    bool? isAuthenticated,
    String? role,
    String? name,
    List<String>? permissions,
    String? errorMessage,
    bool? isLoading,
  }) {
    return UserState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthController extends ChangeNotifier {
  final ApiClient _apiClient;

  UserState _state = UserState();

  AuthController(this._apiClient) {
    restoreSession();
  }

  UserState get state => _state;

  Future<void> restoreSession() async {
    try {
      final token = await _apiClient.storage.read(key: 'jwt_token');

      if (token != null && token.isNotEmpty) {
        final role = await _apiClient.storage.read(key: 'user_role');
        final name = await _apiClient.storage.read(key: 'user_name');
        final permsJson = await _apiClient.storage.read(
          key: 'user_permissions',
        );

        List<String> permissions = [];

        if (permsJson != null) {
          final decoded = jsonDecode(permsJson);

          if (decoded is List) {
            permissions = decoded.map((e) => e.toString()).toList();
          }
        }

        _state = UserState(
          isAuthenticated: true,
          role: role ?? 'WAITER',
          name: name ?? 'Personel',
          permissions: permissions,
          isLoading: false,
        );

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Oturum geri yükleme hatası: $e');
    }
  }

  Future<bool> loginWithPin(
    String pin, {
    String businessSlug = AppConstants.defaultBusinessSlug,
  }) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);

    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        '/auth/login-pin',
        data: {'businessSlug': businessSlug, 'pinCode': pin},
      );

      debugPrint('--> Backend Yanıtı Geldi: ${response.statusCode}');

      final resData = response.data;

      final data = resData['data'] ?? {};

      final token = data['token'];

      final user = data['user'] ?? {};

      final rawPerms = (user['permissions'] as List<dynamic>?) ?? [];

      final permissions = rawPerms.map((p) => p.toString()).toList();

      final userRole = user['role']?.toString() ?? 'WAITER';

      final userName = user['fullName']?.toString() ?? 'Personel';

      if (token != null) {
        await _apiClient.storage.write(
          key: 'jwt_token',
          value: token.toString(),
        );
      }

      await _apiClient.storage.write(key: 'user_role', value: userRole);

      await _apiClient.storage.write(key: 'user_name', value: userName);

      await _apiClient.storage.write(
        key: 'user_permissions',
        value: jsonEncode(permissions),
      );

      _state = UserState(
        isAuthenticated: true,
        role: userRole,
        name: userName,
        permissions: permissions,
        isLoading: false,
      );

      notifyListeners();

      return true;
    } on DioException catch (e) {
      debugPrint('================ LOGIN HATASI ================');
      debugPrint('Dio Type: ${e.type}');
      debugPrint('Message: ${e.message}');
      debugPrint('URL: ${e.requestOptions.uri}');
      debugPrint('Method: ${e.requestOptions.method}');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('================================================');

      final responseData = e.response?.data;

      String errorMsg = 'Giriş başarısız. PIN kontrol edin.';

      if (responseData is Map) {
        errorMsg =
            responseData['error']?.toString() ??
            responseData['message']?.toString() ??
            errorMsg;
      }

      _state = _state.copyWith(isLoading: false, errorMessage: errorMsg);

      notifyListeners();

      return false;
    } catch (e) {
      debugPrint('--> Beklenmeyen Hata: $e');

      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Bağlantı hatası: $e',
      );

      notifyListeners();

      return false;
    }
  }

  Future<void> logout() async {
    await _apiClient.storage.deleteAll();

    _state = UserState();

    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthController>((ref) {
  final client = ref.watch(apiClientProvider);

  return AuthController(client);
});
