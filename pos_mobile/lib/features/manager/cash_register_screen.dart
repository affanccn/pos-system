import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';

class CashRegisterScreen extends ConsumerStatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  ConsumerState<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends ConsumerState<CashRegisterScreen> {
  Map<String, dynamic>? _summary;
  bool _isLoading = false;

  final Map<String, String> _typeLabels = {
    'OPENING': 'Kasa Acilis',
    'CASH_IN': 'Nakit Giris',
    'CASH_OUT': 'Nakit Cikis',
    'EXPENSE': 'Gider',
    'CLOSING': 'Kasa Kapanis',
  };

  final Map<String, Color> _typeColors = {
    'OPENING': Colors.blue,
    'CASH_IN': Colors.green,
    'CASH_OUT': Colors.orange,
    'EXPENSE': Colors.red,
    'CLOSING': Colors.purple,
  };

  final Map<String, IconData> _typeIcons = {
    'OPENING': Icons.lock_open,
    'CASH_IN': Icons.arrow_downward,
    'CASH_OUT': Icons.arrow_upward,
    'EXPENSE': Icons.money_off,
    'CLOSING': Icons.lock,
  };

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/cash/summary');
      setState(() {
        _summary = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddMovementDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'CASH_IN';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setStateDialog) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Kasa Hareketi', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedType,
                dropdownColor: Theme.of(context).dividerColor,
                isExpanded: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                items: _typeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (val) => setStateDialog(() => selectedType = val!),
              ),
              TextField(controller: amountCtrl, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), decoration: InputDecoration(labelText: 'Tutar (TL)', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))), keyboardType: TextInputType.number),
              TextField(controller: descCtrl, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), decoration: InputDecoration(labelText: 'Aciklama', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Iptal')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                final apiClient = ref.read(apiClientProvider);
                try {
                  await apiClient.dio.post('/cash', data: {
                    'type': selectedType,
                    'amountCents': (amount * 100).toInt(),
                    'description': descCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchSummary();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                }
              },
              child: Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, int cents, Color color, IconData icon) {
    return Card(
      color: Theme.of(context).dividerColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${(cents / 100).toStringAsFixed(2)} TL',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Kasa Yonetimi', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchSummary),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMovementDialog,
        backgroundColor: const Color(0xFF38BDF8),
        child: Icon(Icons.add),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _summary == null
          ? Center(child: Text('Veri yok', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gunluk Kasa Ozeti', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildSummaryCard('Acilis', _summary!['openingAmountCents'] ?? 0, Colors.blue, Icons.lock_open),
                      _buildSummaryCard('Nakit Giris', _summary!['cashInCents'] ?? 0, Colors.green, Icons.arrow_downward),
                      _buildSummaryCard('Satis (Nakit)', _summary!['cashFromSalesCents'] ?? 0, Colors.teal, Icons.point_of_sale),
                      _buildSummaryCard('Nakit Cikis', _summary!['cashOutCents'] ?? 0, Colors.orange, Icons.arrow_upward),
                      _buildSummaryCard('Giderler', _summary!['totalExpensesCents'] ?? 0, Colors.red, Icons.money_off),
                      _buildSummaryCard('Beklenen Kasa', _summary!['expectedCashCents'] ?? 0, Colors.cyan, Icons.calculate),
                    ],
                  ),
                  SizedBox(height: 16),
                  if ((_summary!['closingAmountCents'] ?? 0) > 0) ...[
                    Card(
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kapanis / Sayim', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                            Text('${((_summary!['closingAmountCents'] ?? 0) / 100).toStringAsFixed(2)} TL', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Card(
                      color: (_summary!['differenceCents'] ?? 0) >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kasa Farki', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${((_summary!['differenceCents'] ?? 0) / 100).toStringAsFixed(2)} TL', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  Text('Hareketler', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...(_summary!['movements'] as List<dynamic>? ?? []).map((m) {
                    final type = m['type'] as String;
                    final date = DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now();
                    return Card(
                      color: Theme.of(context).dividerColor,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (_typeColors[type] ?? Colors.grey).withValues(alpha: 0.2),
                          child: Icon(_typeIcons[type] ?? Icons.help, color: _typeColors[type] ?? Colors.grey),
                        ),
                        title: Text(_typeLabels[type] ?? type, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        subtitle: Text('${m['description'] ?? ''}\n${dateFormat.format(date)} - ${m['user']?['fullName'] ?? ''}', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                        trailing: Text('${((m['amountCents'] ?? 0) / 100).toStringAsFixed(2)} TL', style: TextStyle(color: _typeColors[type] ?? Colors.grey, fontWeight: FontWeight.bold)),
                        isThreeLine: true,
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
