import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/table_model.dart';
import '../auth/auth_controller.dart';

final selectedSectionProvider = StateProvider<String>((ref) => 'Tümü');

final tablesFutureProvider = FutureProvider.autoDispose<List<RestaurantTable>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);

  try {
    final response = await apiClient.dio.get('/tables');
    final rawData = response.data;
    
    final List<dynamic> list = rawData is List ? rawData : (rawData['data'] ?? []);
    
    return list.map((item) => RestaurantTable.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Masalar yüklenirken hata oluştu: $e');
  }
});

class TableOperationsController {
  final Ref ref;

  TableOperationsController(this.ref);

  Future<void> createTable({
    required String name,
    required String section,
    required int capacity,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.post('/tables', data: {
      'name': name.trim(),
      'section': section.trim(),
      'capacity': capacity,
    });
    ref.invalidate(tablesFutureProvider);
  }

  Future<void> updateTable({
    required String id,
    required String name,
    required String section,
    required int capacity,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.put('/tables/$id', data: {
      'name': name.trim(),
      'section': section.trim(),
      'capacity': capacity,
    });
    ref.invalidate(tablesFutureProvider);
  }

  Future<void> deleteTable(String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.delete('/tables/$id');
    ref.invalidate(tablesFutureProvider);
  }

  Future<void> mergeTables({
    required String sourceTableId,
    required String targetTableId,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.post('/tables/merge', data: {
      'fromTableId': sourceTableId,
      'toTableId': targetTableId,
    });
    ref.invalidate(tablesFutureProvider);
  }

  Future<void> transferTable({
    required String fromTableId,
    required String toTableId,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.post('/tables/transfer', data: {
      'fromTableId': fromTableId,
      'toTableId': toTableId,
    });
    ref.invalidate(tablesFutureProvider);
  }

  Future<void> reorderTables(List<Map<String, dynamic>> items) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.dio.post('/tables/reorder', data: {
      'items': items,
    });
  }
}

final tableOperationsProvider = Provider<TableOperationsController>((ref) {
  return TableOperationsController(ref);
});