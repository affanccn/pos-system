import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/models/staff_model.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

final staffListProvider = FutureProvider.autoDispose<List<StaffUser>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.dio.get('/staff');
    final rawList = (response.data['data'] as List<dynamic>?) ?? [];
    return rawList.map((item) => StaffUser.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('Personel listesi yüklenemedi: $e');
    throw Exception('Personel listesi alınamadı: $e');
  }
});

class StaffService {
  final ApiClient _apiClient;

  StaffService(this._apiClient);

  Future<void> createStaff({
    required String fullName,
    required String pinCode,
    required String role,
    String? email,
    List<String>? customPermissions,
  }) async {
    try {
      await _apiClient.dio.post(
        '/staff',
        data: {
          'fullName': fullName,
          'pinCode': pinCode,
          'role': role,
          'email': email,
          if (customPermissions != null) ...{'customPermissions': customPermissions},
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Personel oluşturulamadı.';
      throw Exception(msg);
    }
  }

  Future<void> updateStaff({
    required String id,
    required String fullName,
    required String role,
    String? email,
    required bool isActive,
    List<String>? customPermissions,
  }) async {
    try {
      await _apiClient.dio.put(
        '/staff/$id',
        data: {
          'fullName': fullName,
          'role': role,
          'email': email,
          'isActive': isActive,
          if (customPermissions != null) ...{'customPermissions': customPermissions},
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Personel güncellenemedi.';
      throw Exception(msg);
    }
  }

  Future<void> updateStaffPin({
    required String id,
    required String newPin,
  }) async {
    try {
      await _apiClient.dio.patch(
        '/staff/$id/pin',
        data: {'pinCode': newPin},
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'PIN güncellenemedi.';
      throw Exception(msg);
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await _apiClient.dio.delete('/staff/$id');
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Personel silinemedi.';
      throw Exception(msg);
    }
  }
}

final staffServiceProvider = Provider<StaffService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StaffService(apiClient);
});
