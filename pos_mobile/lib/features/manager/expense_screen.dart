import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';
import '../../core/widgets/app_states.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  List<dynamic> _expenses = [];
  int _totalCents = 0;
  bool _isLoading = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  final List<Map<String, String>> _categories = [
    {'value': 'RENT', 'label': 'Kira'},
    {'value': 'ELECTRICITY', 'label': 'Elektrik'},
    {'value': 'WATER', 'label': 'Su'},
    {'value': 'STAFF', 'label': 'Personel'},
    {'value': 'SUPPLIES', 'label': 'Malzeme'},
    {'value': 'MAINTENANCE', 'label': 'Bakim'},
    {'value': 'MARKETING', 'label': 'Pazarlama'},
    {'value': 'OTHER', 'label': 'Diger'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  String _categoryLabel(String val) {
    return _categories.firstWhere((c) => c['value'] == val, orElse: () => {'label': val})['label'] ?? val;
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/expenses', queryParameters: {
        'startDate': DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0).toIso8601String(),
        'endDate': DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String(),
      });
      setState(() {
        _expenses = res.data['data'] as List;
        _totalCents = res.data['totalCents'] ?? 0;
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
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _fetchExpenses();
    }
  }

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'OTHER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Yeni Gider', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedCategory,
                dropdownColor: const Color(0xFF334155),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
                onChanged: (val) => setStateDialog(() => selectedCategory = val!),
              ),
              TextField(controller: amountCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Tutar (TL)', labelStyle: TextStyle(color: Colors.white70)), keyboardType: TextInputType.number),
              TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Aciklama', labelStyle: TextStyle(color: Colors.white70))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.dio.post('/expenses', data: {
                    'category': selectedCategory,
                    'amountCents': (amount * 100).toInt(),
                    'description': descCtrl.text,
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _fetchExpenses();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Gider Yonetimi', style: TextStyle(color: Colors.white)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: const Color(0xFF38BDF8),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
        ? const AppLoadingState(message: 'Giderler yükleniyor...')
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1E293B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Toplam Gider:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text('${(_totalCents / 100).toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: _expenses.isEmpty
                  ? AppEmptyState(message: 'Gider bulunamadı.', icon: Icons.money_off, onAction: _showAddExpenseDialog, actionLabel: 'Gider Ekle')
                  : ListView.builder(
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final e = _expenses[index];
                        final date = DateTime.tryParse(e['expenseDate'] ?? '') ?? DateTime.now();
                        return Card(
                          color: const Color(0xFF334155),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                              child: const Icon(Icons.money_off, color: Colors.redAccent),
                            ),
                            title: Text(_categoryLabel(e['category'] ?? ''), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('${e['description'] ?? ''}\n${dateFormat.format(date)} - ${e['user']?['fullName'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${((e['amountCents'] ?? 0) / 100).toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                InkWell(
                                  onTap: () {
                                    showAppDialog(
                                      context: context,
                                      title: 'Gideri Sil',
                                      content: const Text('Bu gider kaydını silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
                                      confirmText: 'Sil',
                                      isDestructive: true,
                                      onConfirm: () async {
                                        final apiClient = ref.read(apiClientProvider);
                                        await apiClient.dio.delete('/expenses/${e['id']}');
                                        if (context.mounted) Navigator.pop(context);
                                        _fetchExpenses();
                                      },
                                    );
                                  },
                                  child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                )
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}
