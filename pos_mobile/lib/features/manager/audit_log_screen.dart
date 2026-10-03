import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';
import '../../core/widgets/app_states.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = false;
  int _page = 1;
  int _totalPages = 1;
  String? _actionFilter;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  final Map<String, String> _actionLabels = {
    'ORDER_CREATED': 'Sipariş Oluşturma',
    'ORDER_UPDATE': 'Sipariş Düzenleme / Masa Aktarımı',
    'ORDER_CANCEL': 'Sipariş İptal',
    'PRODUCT_DELETE': 'Ürün Silme',
    'ITEM_VOID': 'Kalem İptali (Void)',
    'ITEM_DISCOUNT': 'İndirim',
    'ITEM_COMPLIMENTARY': 'İkram',
    'ITEM_RETURN': 'İade',
    'PAYMENT_CREATE': 'Ödeme Alındı',
    'CASH_MOVEMENT': 'Kasa Hareketi',
    'STOCK_CHANGE': 'Stok Değişimi',
    'PRICE_CHANGE': 'Fiyat Değişimi',
    'STAFF_CHANGE': 'Personel Değişimi',
    'PERMISSION_CHANGE': 'Yetki Değişimi',
    'EXPENSE_CREATE': 'Gider Kaydı',
    'EXPENSE_DELETE': 'Gider Silme',
  };

  final Map<String, Color> _actionColors = {
    'ORDER_CREATED': Colors.green,
    'ORDER_UPDATE': Colors.blue,
    'ORDER_CANCEL': Colors.red,
    'PRODUCT_DELETE': Colors.red,
    'ITEM_VOID': Colors.orange,
    'ITEM_DISCOUNT': Colors.amber,
    'ITEM_COMPLIMENTARY': Colors.purple,
    'ITEM_RETURN': Colors.pink,
    'PAYMENT_CREATE': Colors.teal,
    'CASH_MOVEMENT': Colors.cyan,
    'STOCK_CHANGE': Colors.lime,
    'PRICE_CHANGE': Colors.deepOrange,
    'STAFF_CHANGE': Colors.indigo,
    'PERMISSION_CHANGE': Colors.deepPurple,
    'EXPENSE_CREATE': Colors.redAccent,
    'EXPENSE_DELETE': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final params = <String, dynamic>{
        'startDate': DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0).toIso8601String(),
        'endDate': DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String(),
        'page': _page,
        'limit': 50,
      };
      if (_actionFilter != null) params['action'] = _actionFilter;

      final res = await apiClient.dio.get('/audit', queryParameters: params);
      setState(() {
        _logs = res.data['data'] as List;
        _totalPages = res.data['pagination']?['totalPages'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF38BDF8), surface: Color(0xFF1E293B), onSurface: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; _page = 1; });
      _fetchLogs();
    }
  }

  void _showDetailDialog(dynamic log) {
    showAppDialog(
      context: context,
      title: _actionLabels[log['action']] ?? log['action'] ?? 'İşlem Detayı',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('Kullanici', log['user']?['fullName'] ?? 'Bilinmiyor'),
            _detailRow('Islem', log['action'] ?? ''),
            _detailRow('Varlik', log['entity'] ?? '-'),
            _detailRow('Varlik ID', log['entityId'] ?? '-'),
            _detailRow('Tarih', _formatDate(log['createdAt'])),
            if (log['description'] != null) _detailRow('Aciklama', log['description']),
            if (log['oldValue'] != null) ...[
              const SizedBox(height: 12),
              const Text('Eski Deger:', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                child: Text('${log['oldValue']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
            if (log['newValue'] != null) ...[
              const SizedBox(height: 12),
              const Text('Yeni Deger:', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                child: Text('${log['newValue']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
      cancelText: 'Kapat',
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(color: Colors.white70))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Islem Gecmisi', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
            label: Text('${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Text('Filtre: ', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _actionFilter,
                    dropdownColor: const Color(0xFF334155),
                    isExpanded: true,
                    hint: const Text('Tum Islemler', style: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tum Islemler')),
                      ..._actionLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (val) {
                      setState(() { _actionFilter = val; _page = 1; });
                      _fetchLogs();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
              ? const AppLoadingState(message: 'Loglar yükleniyor...')
              : _logs.isEmpty
                ? const AppEmptyState(
                    icon: Icons.history,
                    message: 'İşlem Bulunamadı',
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final action = log['action'] as String? ?? '';
                      final color = _actionColors[action] ?? Colors.grey;
                      return Card(
                        color: const Color(0xFF334155),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(Icons.history, color: color, size: 20),
                          ),
                          title: Text(_actionLabels[action] ?? action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${log['user']?['fullName'] ?? ''} | ${_formatDate(log['createdAt'])}${log['description'] != null ? '\n${log['description']}' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          onTap: () => _showDetailDialog(log),
                          isThreeLine: log['description'] != null,
                        ),
                      );
                    },
                  ),
          ),
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E293B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: _page > 1 ? () { setState(() => _page--); _fetchLogs(); } : null,
                  ),
                  Text('Sayfa $_page / $_totalPages', style: const TextStyle(color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: _page < _totalPages ? () { setState(() => _page++); _fetchLogs(); } : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
