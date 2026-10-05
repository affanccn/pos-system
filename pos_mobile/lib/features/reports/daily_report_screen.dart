import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';
import '../../core/widgets/app_states.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/reports/end-of-day/preview', queryParameters: {
        'date': _selectedDate.toIso8601String(),
      });
      setState(() {
        _reportData = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor alınamadı: $e')));
      }
    }
  }

  Future<void> _closeDay(int actualCashCents) async {
    if (_reportData == null) return;
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.dio.post('/reports/end-of-day/close', data: {
        'reportDate': _selectedDate.toIso8601String(),
        'actualCashCents': actualCashCents,
        'data': _reportData,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gün sonu başarıyla kapatıldı.')));
        _fetchReport();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kapanış başarısız: $e')));
      }
    }
  }

  void _showCloseDayDialog() {
    final expectedCashCents = _reportData?['expectedCashCents'] ?? 0;
    final expectedCashStr = (expectedCashCents / 100).toStringAsFixed(2);
    final controller = TextEditingController(text: expectedCashStr);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Kasa Kapanışı Yap (Z Raporu)', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gün sonunu kapatmak üzeresiniz. Bu işlem geri alınamaz.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Text('Sistemdeki Beklenen Kasa: $expectedCashStr ₺', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Gerçek Kasa (Sayım Sonucu) ₺',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () {
                final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
                final actualCents = (val * 100).round();
                Navigator.pop(context);
                _closeDay(actualCents);
              },
              child: const Text('Kapat (Z Raporu Al)'),
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(int cents) {
    return '${(cents / 100).toStringAsFixed(2)} ₺';
  }

  Widget _buildRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            _formatCurrency(value),
            style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Gün Sonu (Z Raporu)', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Color(0xFF38BDF8), size: 16),
            label: Text(
              dateFormat.format(_selectedDate),
              style: const TextStyle(color: Color(0xFF38BDF8)),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _fetchReport();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReport),
        ],
      ),
      body: _isLoading
          ? const AppLoadingState(message: 'Gün sonu raporu hazırlanıyor...')
          : _reportData == null
              ? AppEmptyState(message: 'Veri bulunamadı.', icon: Icons.receipt_long, onAction: _fetchReport, actionLabel: 'Yenile')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_reportData!['isAlreadyClosed'] == true)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            border: Border.all(color: const Color(0xFF10B981)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Expanded(child: Text('Bu güne ait gün sonu kapatılmış.', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                      
                      Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Satış Özeti', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(color: Color(0xFF334155)),
                              _buildRow('Toplam Satış (Brüt)', _reportData!['totalSalesCents'] ?? 0),
                              _buildRow('Nakit', _reportData!['cashCents'] ?? 0, color: const Color(0xFF38BDF8)),
                              _buildRow('Kredi Kartı', _reportData!['cardCents'] ?? 0, color: const Color(0xFFF59E0B)),
                              const Divider(color: Color(0xFF334155)),
                              _buildRow('İndirimler', _reportData!['discountCents'] ?? 0, color: const Color(0xFFEF4444)),
                              _buildRow('İkramlar', _reportData!['complimentaryCents'] ?? 0, color: const Color(0xFFA78BFA)),
                              _buildRow('İadeler', _reportData!['returnedCents'] ?? 0, color: const Color(0xFFF43F5E)),
                            ],
                          ),
                        ),
                      ),

                      Card(
                        color: const Color(0xFF1E293B),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nakit Kasa', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(color: Color(0xFF334155)),
                              _buildRow('Açılış Kasası', _reportData!['openingCashCents'] ?? 0),
                              _buildRow('Nakit Satışlar (+)', _reportData!['cashCents'] ?? 0),
                              _buildRow('Giderler / Nakit Çıkışı (-)', _reportData!['expensesCents'] ?? 0, color: const Color(0xFFEF4444)),
                              const Divider(color: Color(0xFF334155)),
                              _buildRow('Beklenen Kasa', _reportData!['expectedCashCents'] ?? 0, color: const Color(0xFF38BDF8)),
                              
                              if (_reportData!['isAlreadyClosed'] == true) ...[
                                _buildRow('Gerçek Kasa (Sayım)', _reportData!['actualCashCents'] ?? 0, color: const Color(0xFF10B981)),
                                _buildRow('Fark', _reportData!['differenceCents'] ?? 0, color: ((_reportData!['differenceCents'] ?? 0) < 0) ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                              ]
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      if (_reportData!['isAlreadyClosed'] == false)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lock_outline, color: Colors.white),
                          label: const Text('KASAYI KAPAT (Z RAPORU AL)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _showCloseDayDialog,
                        ),
                    ],
                  ),
                ),
    );
  }
}