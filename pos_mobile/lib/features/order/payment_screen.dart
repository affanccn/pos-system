import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String tableId;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.tableId,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _order;
  List<dynamic> _items = [];

  int _totalAmountCents = 0;
  int _paidAmountCents = 0;
  int _discountAmountCents = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(
        '/orders/table/${widget.tableId}',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        setState(() {
          _order = response.data['data'];
          _items = _order?['items'] ?? [];
          _totalAmountCents = _order?['totalAmountCents'] ?? 0;
          _paidAmountCents = _order?['paidAmountCents'] ?? 0;
          _discountAmountCents = _order?['discountAmountCents'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayment(
    String method,
    int amountCents, {
    List<Map<String, dynamic>>? paidItems,
  }) async {
    if (amountCents <= 0) return;

    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final requestData = <String, dynamic>{
        'method': method,
        'amountCents': amountCents,
      };
      if (paidItems != null) {
        requestData['paidItems'] = paidItems;
      }
      
      final response = await apiClient.dio.post(
        '/orders/${widget.orderId}/payment',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isFullyPaid = response.data['data']['isFullyPaid'] ?? false;
        if (isFullyPaid) {
          if (mounted) {
            context.go('/');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hesap tamamen kapandı.')),
            );
          }
        } else {
          await _fetchOrder();
          setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_order == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Ödeme'),
          backgroundColor: Theme.of(context).cardColor,
        ),
        body: Center(
          child: Text(
            'Sipariş bulunamadı.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    }

    final remaining =
        _totalAmountCents - _paidAmountCents - _discountAmountCents;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Ödeme - Masa ${_order!['table']['name']}'),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isVoid = item['status'] == 'VOID';
                  final paidQty = item['paidQuantity'] ?? 0;
                  final totalQty = item['quantity'] ?? 1;

                  return ListTile(
                    title: Text(
                      item['productNameSnapshot'] ?? '',
                      style: TextStyle(
                        color: isVoid ? Colors.red : Colors.white,
                        decoration: isVoid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      '$paidQty / $totalQty ödendi',
                      style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54)),
                    ),
                    trailing: Text(
                      '${(item['totalPriceCents'] / 100).toStringAsFixed(2)} ₺',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ÖZET',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSummaryRow('Ara Toplam', _totalAmountCents),
                  _buildSummaryRow(
                    'İndirim',
                    _discountAmountCents,
                    color: Colors.green,
                  ),
                  _buildSummaryRow(
                    'Ödenen',
                    _paidAmountCents,
                    color: Colors.amber,
                  ),
                  Divider(color: Theme.of(context).dividerColor),
                  _buildSummaryRow(
                    'KALAN',
                    remaining > 0 ? remaining : 0,
                    isLarge: true,
                  ),
                  Spacer(),

                  if (remaining > 0) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => _processPayment('CASH', remaining),
                      icon: Icon(Icons.money, color: Theme.of(context).colorScheme.onSurface),
                      label: Text(
                        'Nakit',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => _processPayment('CARD', remaining),
                      icon: Icon(Icons.credit_card, color: Theme.of(context).colorScheme.onSurface),
                      label: Text(
                        'Kredi Kartı',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => _processPayment('ACCOUNT', remaining),
                      icon: Icon(
                        Icons.account_balance_wallet,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      label: Text(
                        'Cari Hesaba Yaz',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Text(
                        'HESAP KAPANDI',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    int cents, {
    Color color = Colors.white,
    bool isLarge = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
              fontSize: isLarge ? 20 : 16,
            ),
          ),
          Text(
            '${(cents / 100).toStringAsFixed(2)} ₺',
            style: TextStyle(
              color: color,
              fontSize: isLarge ? 24 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
