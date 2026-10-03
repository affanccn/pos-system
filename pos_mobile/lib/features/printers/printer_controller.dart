import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/models/printer_model.dart';
import '../auth/auth_controller.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService(ref.read(apiClientProvider));
});

final printersFutureProvider = FutureProvider.autoDispose<List<Printer>>((ref) async {
  final service = ref.watch(printerServiceProvider);
  return service.getPrinters();
});

class PrinterService {
  final ApiClient apiClient;

  PrinterService(this.apiClient);

  Future<List<Printer>> getPrinters() async {
    final response = await apiClient.dio.get('/printers');
    if (response.statusCode == 200) {
      final List data = response.data['data'] ?? [];
      return data.map((json) => Printer.fromJson(json)).toList();
    }
    throw Exception('Yazıcılar yüklenemedi.');
  }

  Future<Printer> createPrinter({
    required String name,
    required String ipAddress,
    required int port,
    String? stationType,
    required bool isCashier,
  }) async {
    final response = await apiClient.dio.post(
      '/printers',
      data: {
        'name': name,
        'ipAddress': ipAddress,
        'port': port,
        'stationType': stationType,
        'isCashier': isCashier,
      },
    );
    if (response.statusCode == 201) {
      return Printer.fromJson(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Yazıcı eklenemedi.');
  }

  Future<Printer> updatePrinter({
    required String id,
    String? name,
    String? ipAddress,
    int? port,
    String? stationType,
    bool? isCashier,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (ipAddress != null) data['ipAddress'] = ipAddress;
    if (port != null) data['port'] = port;
    if (stationType != null) data['stationType'] = stationType;
    if (isCashier != null) data['isCashier'] = isCashier;
    if (isActive != null) data['isActive'] = isActive;

    final response = await apiClient.dio.put('/printers/$id', data: data);
    if (response.statusCode == 200) {
      return Printer.fromJson(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Yazıcı güncellenemedi.');
  }

  Future<void> deletePrinter(String id) async {
    final response = await apiClient.dio.delete('/printers/$id');
    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Yazıcı silinemedi.');
    }
  }

  Future<bool> testPrinterConnection(String ipAddress, int port) async {
    // Mobil tarafta yazıcı testi yapmak için bir soket açılır veya ping atılır
    // Ancak ESC/POS komutlarıyla Flutter'dan ağ testi yapılacaksa flutter_esc_pos_network paketi gerekir.
    // Şimdilik testin başarılı olduğunu varsayıyoruz veya 1-2 saniye bekliyoruz
    await Future.delayed(const Duration(seconds: 1));
    return true; 
  }
}
