import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/table_model.dart';
import '../auth/auth_controller.dart';
import '../waiter/tables_controller.dart';

import 'package:go_router/go_router.dart';

import '../../core/auth/permissions.dart';
import '../../core/widgets/app_states.dart';

final tableActiveOrderProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, tableId) async {
      final apiClient = ref.watch(apiClientProvider);
      try {
        final response = await apiClient.dio.get('/orders/table/$tableId');
        return response.data['data'] as Map<String, dynamic>?;
      } catch (e) {
        return null;
      }
    });

class TableDetailScreen extends ConsumerStatefulWidget {
  final RestaurantTable table;

  const TableDetailScreen({super.key, required this.table});

  @override
  ConsumerState<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends ConsumerState<TableDetailScreen> {
  bool _isProcessing = false;

  Future<void> _requestBill() async {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.orderEdit)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Hesap isteme yetkiniz bulunmamaktadır.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (widget.table.status == 'BILL_REQUESTED') {
      final shouldReprint = await showAppDialog<bool>(
        context: context,
        title: 'Tekrar Yazdır?',
        content: const Text('Hesap zaten istenmiş. Fiş tekrar yazdırılsın mı?', style: TextStyle(color: Colors.white70)),
        confirmText: 'Yazdır',
        onConfirm: () => Navigator.of(context).pop(true),
      );
      if (shouldReprint != true) return;
    }

    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/table/${widget.table.id}/bill-request',
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hesap isteme talebi iletildi! Masa durumu güncellendi.',
            ),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hesap istenemedi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executePayment({
    required String orderId,
    required int amountCents,
    required String method,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/$orderId/payment',
        data: {'amountCents': amountCents, 'method': method},
      );

      if (response.statusCode == 200 && mounted) {
        final isFullyPaid = response.data['isFullyPaid'] as bool? ?? false;
        final message =
            response.data['message'] as String? ?? 'Ödeme başarıyla alındı.';

        ref.invalidate(tablesFutureProvider);

        if (isFullyPaid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFF38BDF8),
            ),
          );
          ref.invalidate(tableActiveOrderProvider(widget.table.id));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ödeme alınamadı: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _closeTable() async {
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/table/${widget.table.id}/close',
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masa başarıyla kapatıldı.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa kapatılamadı: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeItemComplimentary(String orderItemId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/items/$orderItemId/complimentary',
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        ref.invalidate(tableActiveOrderProvider(widget.table.id));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ürün başarıyla ikram edildi.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('İkram işlemi başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDiscountDialog(String orderId, int currentRemainingCents) {
    final discountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('İndirim Uygula', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kalan Tutar: ${(currentRemainingCents / 100).toStringAsFixed(2)} ₺', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'İndirim Tutarı (₺)',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountStr = discountController.text.replaceAll(',', '.');
                final amount = double.tryParse(amountStr);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir tutar girin.')));
                  return;
                }
                final discountCents = (amount * 100).toInt();
                if (discountCents > currentRemainingCents) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İndirim tutarı kalan tutardan büyük olamaz.')));
                   return;
                }
                Navigator.pop(ctx);
                await _executeOrderDiscount(orderId, discountCents);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Uygula', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeOrderDiscount(String orderId, int discountAmountCents) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/$orderId/discount',
        data: {'discountAmountCents': discountAmountCents},
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        ref.invalidate(tableActiveOrderProvider(widget.table.id));
        messenger.showSnackBar(
          SnackBar(
            content: Text('${(discountAmountCents / 100).toStringAsFixed(2)} ₺ indirim uygulandı.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('İndirim başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPaymentModal({required String orderId, required int totalCents, required int paidCents}) {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.paymentCreate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Ödeme alma yetkiniz bulunmamaktadır (Kasiyer / Yetkili gereklidir).',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final remainingCents = totalCents - paidCents;
    final remainingLira = remainingCents / 100;

    final TextEditingController amountController = TextEditingController(
      text: remainingLira.toStringAsFixed(2),
    );
    String selectedMethod = 'CASH';
    int activeSplit = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.table.name} • Tahsilat Yap',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kalan Ödenecek:',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${remainingLira.toStringAsFixed(2)} ₺',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Ödeme Yöntemi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => selectedMethod = 'CASH'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedMethod == 'CASH'
                                    ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.2)
                                    : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedMethod == 'CASH'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF334155),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    color: selectedMethod == 'CASH'
                                        ? const Color(0xFF10B981)
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Nakit',
                                    style: TextStyle(
                                      color: selectedMethod == 'CASH'
                                          ? const Color(0xFF10B981)
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => selectedMethod = 'CARD'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedMethod == 'CARD'
                                    ? const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.2)
                                    : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedMethod == 'CARD'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF334155),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.credit_card,
                                    color: selectedMethod == 'CARD'
                                        ? const Color(0xFF38BDF8)
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kredi Kartı',
                                    style: TextStyle(
                                      color: selectedMethod == 'CARD'
                                          ? const Color(0xFF38BDF8)
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Tahsil Edilecek Tutar (₺)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        suffixText: '₺',
                        suffixStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF334155),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeSplit == 1 ? const Color(0xFF38BDF8) : Colors.white70,
                              side: BorderSide(color: activeSplit == 1 ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              setModalState(() {
                                activeSplit = 1;
                                amountController.text = remainingLira.toStringAsFixed(2);
                              });
                            },
                            child: const Text('Tamamı'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeSplit == 2 ? const Color(0xFF38BDF8) : Colors.white70,
                              side: BorderSide(color: activeSplit == 2 ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              setModalState(() {
                                activeSplit = 2;
                                amountController.text = (remainingLira / 2).toStringAsFixed(2);
                              });
                            },
                            child: const Text('1/2 (2 Kişi)'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeSplit == 3 ? const Color(0xFF38BDF8) : Colors.white70,
                              side: BorderSide(color: activeSplit == 3 ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              setModalState(() {
                                activeSplit = 3;
                                amountController.text = (remainingLira / 3).toStringAsFixed(2);
                              });
                            },
                            child: const Text('1/3 (3 Kişi)'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeSplit == 4 ? const Color(0xFF38BDF8) : Colors.white70,
                              side: BorderSide(color: activeSplit == 4 ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              setModalState(() {
                                activeSplit = 4;
                                amountController.text = (remainingLira / 4).toStringAsFixed(2);
                              });
                            },
                            child: const Text('1/4 (4 Kişi)'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final parsedLira = double.tryParse(
                            amountController.text.replaceAll(',', '.'),
                          );
                          if (parsedLira == null || parsedLira <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lütfen geçerli bir tutar girin.',
                                ),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }
                          final payCents = (parsedLira * 100).round();
                          if (payCents > remainingCents) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Girilen tutar kalan bakiyeden (${remainingLira.toStringAsFixed(2)} ₺) fazla olamaz.',
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          Navigator.of(ctx).pop();
                          _executePayment(
                            orderId: orderId,
                            amountCents: payCents,
                            method: selectedMethod,
                          );
                        },
                        child: const Text(
                          'Ödemeyi Al ve Kaydet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeVoidItem({
    required String orderItemId,
    required String productName,
    required int cancelQuantity,
    required int currentQuantity,
    required int totalItemsCount,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.delete(
        '/orders/items/$orderItemId?quantityToCancel=$cancelQuantity',
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);

        if (totalItemsCount <= 1 && cancelQuantity >= currentQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Adisyondaki tüm ürünler iptal edildi. Masa boşa çıkarıldı.',
              ),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cancelQuantity adet $productName düşürüldü.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          ref.invalidate(tableActiveOrderProvider(widget.table.id));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showVoidDialog({
    required String orderItemId,
    required String productName,
    required int currentQuantity,
    required int totalItemsCount,
  }) {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.orderVoid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Kalem iptali (Void) işlemi için yetkiniz bulunmuyor. Lütfen Müdüre danışın.',
          ),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (currentQuantity == 1) {
      showAppDialog(
        context: context,
        title: 'Ürün İptali',
        content: Text(
          '$productName adisyondan silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        confirmText: 'Sil',
        isDestructive: true,
        onConfirm: () {
          Navigator.of(context).pop();
          _executeVoidItem(
            orderItemId: orderItemId,
            productName: productName,
            cancelQuantity: 1,
            currentQuantity: currentQuantity,
            totalItemsCount: totalItemsCount,
          );
        },
      );
      return;
    }

    int selectedCancelQty = 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Adisyonda toplam $currentQuantity adet var',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 24),
                  const Text(
                    'İptal Edilecek Adet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: selectedCancelQty > 1
                            ? () => setSheetState(() => selectedCancelQty--)
                            : null,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          '$selectedCancelQty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF10B981),
                        ),
                        onPressed: selectedCancelQty < currentQuantity
                            ? () => setSheetState(() => selectedCancelQty++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _executeVoidItem(
                              orderItemId: orderItemId,
                              productName: productName,
                              cancelQuantity: currentQuantity,
                              currentQuantity: currentQuantity,
                              totalItemsCount: totalItemsCount,
                            );
                          },
                          child: Text(
                            'Tümünü Sil ($currentQuantity)',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _executeVoidItem(
                              orderItemId: orderItemId,
                              productName: productName,
                              cancelQuantity: selectedCancelQty,
                              currentQuantity: currentQuantity,
                              totalItemsCount: totalItemsCount,
                            );
                          },
                          child: Text(
                            '$selectedCancelQty Adet Düş',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTransferDialog(List<dynamic> orderItems) {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.tableTransfer)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Masa taşıma yetkiniz bulunmamaktadır.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final tablesState = ref.read(tablesFutureProvider);

    tablesState.whenData((allTables) {
      final availableTables = allTables
          .where((t) => t.status == 'AVAILABLE' && t.id != widget.table.id)
          .toList();

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          if (availableTables.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Aktarılabilecek boş masa bulunmuyor.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.table.name} ➔ Hedef Masayı Seçin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF334155)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableTables.length,
                    itemBuilder: (context, index) {
                      final target = availableTables[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF10B981),
                          child: Icon(
                            Icons.table_restaurant,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          target.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Kapasite: ${target.capacity} Kişi',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white54,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showTransferItemsSelectionDialog(target, orderItems);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showTransferItemsSelectionDialog(RestaurantTable targetTable, List<dynamic> items) {
    if (items.isEmpty) return;

    final Map<String, int> selectedItems = {};
    for (var item in items) {
      selectedItems[item['id']] = 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isAllSelected = selectedItems.values.every((qty) => qty > 0);
            
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.table.name} ➔ ${targetTable.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF334155), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aktarılacak Ürünleri Seçin',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (isAllSelected) {
                                for (var item in items) {
                                  selectedItems[item['id']] = 0;
                                }
                              } else {
                                for (var item in items) {
                                  selectedItems[item['id']] = item['quantity'] ?? 1;
                                }
                              }
                            });
                          },
                          child: Text(
                            isAllSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                            style: const TextStyle(color: Color(0xFF38BDF8)),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final itemId = item['id'];
                        final name = item['productNameSnapshot'] ?? 'Ürün';
                        final maxQty = item['quantity'] ?? 1;
                        final currentQty = selectedItems[itemId]!;
                        final isSelected = currentQty > 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF10B981).withValues(alpha: 0.1) 
                                : const Color(0xFF0F172A),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: const Color(0xFF94A3B8),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFF10B981),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF94A3B8)),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedItems[itemId] = maxQty;
                                  } else {
                                    selectedItems[itemId] = 0;
                                  }
                                });
                              },
                              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('Adisyonda: $maxQty adet', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              secondary: isSelected && maxQty > 1
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                                          onPressed: currentQty > 1
                                              ? () => setModalState(() => selectedItems[itemId] = currentQty - 1)
                                              : null,
                                        ),
                                        Text('$currentQty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                                          onPressed: currentQty < maxQty
                                              ? () => setModalState(() => selectedItems[itemId] = currentQty + 1)
                                              : null,
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      border: Border(top: BorderSide(color: Color(0xFF334155))),
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: selectedItems.values.any((q) => q > 0)
                              ? () {
                                  Navigator.of(ctx).pop();
                                  
                                  bool allSelected = true;
                                  final transferList = <Map<String, dynamic>>[];
                                  for (var item in items) {
                                    int q = selectedItems[item['id']]!;
                                    if (q > 0) {
                                      transferList.add({'orderItemId': item['id'], 'quantity': q});
                                    }
                                    if (q != item['quantity']) allSelected = false;
                                  }

                                  if (allSelected) {
                                    _executeTransfer(targetTable.id, targetTable.name);
                                  } else {
                                    _executePartialTransfer(targetTable.id, targetTable.name, transferList);
                                  }
                                }
                              : null,
                          child: const Text('Seçili Ürünleri Aktar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executePartialTransfer(String targetTableId, String targetTableName, List<Map<String, dynamic>> items) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/orders/transfer-items',
        data: {
          'fromTableId': widget.table.id,
          'toTableId': targetTableId,
          'items': items,
        },
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        ref.invalidate(tableActiveOrderProvider(widget.table.id));
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Seçili ürünler $targetTableName masasına başarıyla aktarıldı!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ürün aktarımı başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeTransfer(
    String targetTableId,
    String targetTableName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/tables/transfer',
        data: {'fromTableId': widget.table.id, 'toTableId': targetTableId},
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${widget.table.name} masası $targetTableName masasına taşındı!',
            ),
            backgroundColor: const Color(0xFF38BDF8),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Taşıma işlemi başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  Future<void> _executeTableMerge(String targetTableId, String targetTableName) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/tables/merge',
        data: {'fromTableId': widget.table.id, 'toTableId': targetTableId},
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text('${widget.table.name} masası $targetTableName ile birleştirildi!'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Birleştirme başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showTableMergeDialog() {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.tableMerge)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masa birleştirme yetkiniz bulunmamaktadır.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final tablesState = ref.read(tablesFutureProvider);
    tablesState.whenData((allTables) {
      final candidateTables = allTables
          .where((t) => t.status == 'OCCUPIED' && t.id != widget.table.id)
          .toList();

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          if (candidateTables.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Birleştirilebilecek dolu masa bulunmuyor.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hangi Masayla Birleştirilsin?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidateTables.length,
                    itemBuilder: (ctx, index) {
                      final targetTable = candidateTables[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF59E0B),
                          child: Icon(Icons.table_restaurant, color: Colors.white),
                        ),
                        title: Text(
                          targetTable.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Bölüm: ${targetTable.section}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _executeTableMerge(targetTable.id, targetTable.name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showMergeDialog() {
    final userState = ref.read(authProvider).state;
    if (!userState.hasPermission(AppPermissions.tableMerge)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ürün aktarma yetkiniz bulunmamaktadır.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final tablesState = ref.read(tablesFutureProvider);

    tablesState.whenData((allTables) {
      final candidateTables = allTables
          .where((t) => t.id != widget.table.id)
          .toList();

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          if (candidateTables.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Aktarım yapılabilecek başka masa bulunmuyor.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.table.name} ➔ Hedef Masa Seçin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF334155)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidateTables.length,
                    itemBuilder: (context, index) {
                      final target = candidateTables[index];
                      final isOccupied = target.status != 'AVAILABLE';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isOccupied
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          child: Icon(
                            isOccupied
                                ? Icons.receipt_long
                                : Icons.table_restaurant,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          target.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          isOccupied
                              ? 'Dolu (Ürünler adisyona eklenecek)'
                              : 'Boş (Sipariş taşınacak)',
                          style: TextStyle(
                            color: isOccupied
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.call_merge,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _confirmMergeWith(target);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _confirmMergeWith(RestaurantTable target) {
    showAppDialog(
      context: context,
      title: 'Ürünleri Aktarma Onayı',
      content: Text(
        '${widget.table.name} masasındaki tüm ürünler ${target.name} masasına aktarılacak.\n\nİki masanın tüm ürünleri tek adisyonda toplanacak ve ${widget.table.name} boşaltılacaktır. Onaylıyor musunuz?',
        style: const TextStyle(color: Colors.white70),
      ),
      confirmText: 'Birleştir',
      onConfirm: () {
        Navigator.of(context).pop();
        _executeMerge(target.id, target.name);
      },
    );
  }

  Future<void> _executeMerge(
    String targetTableId,
    String targetTableName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/tables/merge',
        data: {'fromTableId': widget.table.id, 'toTableId': targetTableId},
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(tablesFutureProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${widget.table.name} masasındaki ürünler $targetTableName masasına başarıyla aktarıldı!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Masa birleştirme başarısız: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(tableActiveOrderProvider(widget.table.id));
    final userState = ref.watch(authProvider).state;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '${widget.table.name} • Adisyon Detayı',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          if (userState.hasPermission(AppPermissions.tableMerge))
            IconButton(
              tooltip: 'Masayı Birleştir',
              icon: const Icon(
                Icons.merge_type,
                color: Color(0xFFEF4444),
                size: 26,
              ),
              onPressed: _isProcessing ? null : _showTableMergeDialog,
            ),
          if (userState.hasPermission(AppPermissions.tableMerge))
            IconButton(
              tooltip: 'Ürünleri Aktar',
              icon: const Icon(
                Icons.call_split,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
              onPressed: _isProcessing ? null : _showMergeDialog,
            ),
          if (userState.hasPermission(AppPermissions.tableTransfer))
            IconButton(
              tooltip: 'Masayı Taşı',
              icon: const Icon(
                Icons.swap_horiz,
                color: Color(0xFF38BDF8),
                size: 26,
              ),
              onPressed: _isProcessing
                  ? null
                  : () {
                      final order = orderAsync.value;
                      final items = order != null ? (order['items'] as List<dynamic>?) ?? [] : [];
                      _showTransferDialog(items);
                    },
            ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () =>
                ref.invalidate(tableActiveOrderProvider(widget.table.id)),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
        error: (err, _) => _buildEmptyOrderView(context),
        data: (order) {
          if (order == null) {
            return _buildEmptyOrderView(context);
          }

          final allItems = (order['items'] as List<dynamic>?) ?? [];
          final items = allItems.where((item) => item['status'] != 'VOID' && item['status'] != 'CANCELLED').toList();

          final waiter = order['waiter']?['fullName'] ?? 'Bilinmiyor';
          final orderNumber = order['orderNumber'] ?? '-';
          final totalAmountCents = order['totalAmountCents'] as int? ?? 0;
          final orderId = order['id'] as String;

          final paidAmountCents = order['paidAmountCents'] as int? ?? 0;
          final remainingAmountCents = totalAmountCents - paidAmountCents;

          final totalAmount = (totalAmountCents / 100).toStringAsFixed(2);
          final paidAmount = (paidAmountCents / 100).toStringAsFixed(2);
          final remainingAmount = (remainingAmountCents / 100).toStringAsFixed(
            2,
          );

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sipariş #$orderNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Garson: $waiter',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Toplam Tutar',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalAmount ₺',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (paidAmountCents > 0) ...[
                      const Divider(color: Color(0xFF334155), height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tahsil Edilen: $paidAmount ₺',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.pending_outlined,
                                color: Color(0xFFF59E0B),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kalan: $remainingAmount ₺',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sipariş Kalemleri',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF334155), height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemId = item['id'] as String;
                    final name = item['productNameSnapshot'] ?? 'Ürün';
                    final quantity = item['quantity'] ?? 1;
                    final totalItemPrice =
                        ((item['totalPriceCents'] ?? 0) / 100).toStringAsFixed(
                          2,
                        );
                    final note = item['notes'];
                    final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (modifiers.isNotEmpty)
                            ...modifiers.map((mod) => Text(
                              '+ ${mod['modifierNameSnapshot']} ${mod['quantity'] > 1 ? '(x${mod['quantity']})' : ''}',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                            )),
                          if (note != null && note.toString().isNotEmpty)
                            Text(
                              'Not: $note',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12,
                              ),
                            )
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF334155),
                        radius: 16,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalItemPrice ₺',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.card_giftcard,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                            tooltip: 'İkram Et',
                            onPressed: _isProcessing
                                ? null
                                : () => _executeItemComplimentary(itemId),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Color(0xFFEF4444),
                              size: 22,
                            ),
                            tooltip: 'Adet Düş / İptal Et',
                            onPressed: _isProcessing
                                ? null
                                : () => _showVoidDialog(
                                    orderItemId: itemId,
                                    productName: name,
                                    currentQuantity: quantity,
                                    totalItemsCount: items.length,
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : () {
                                      context
                                          .push(
                                            '/waiter/order',
                                            extra: {
                                              'table': widget.table,
                                              'existingOrderId': orderId,
                                            },
                                          )
                                          .then((_) {
                                            ref.invalidate(
                                              tableActiveOrderProvider(
                                                widget.table.id,
                                              ),
                                            );
                                          });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text(
                                'Ürün Ekle',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _requestBill,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.receipt, size: 20),
                              label: const Text(
                                'Hesap İste',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : () => _showDiscountDialog(orderId, remainingAmountCents),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.discount, size: 20),
                              label: const Text(
                                'İndirim',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  if (remainingAmountCents <= 0) {
                                    _closeTable();
                                  } else {
                                    _showPaymentModal(
                                      orderId: orderId,
                                      totalCents: totalAmountCents,
                                      paidCents: paidAmountCents,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.point_of_sale),
                          label: Text(
                            paidAmountCents > 0
                                ? 'Kalanı Öde ($remainingAmount ₺)'
                                : (remainingAmountCents <= 0 
                                    ? 'Hesabı Kapat' 
                                    : 'Ödeme Al / Hesabı Kapat ($totalAmount ₺)'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrderView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF94A3B8), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Bu masada aktif bir sipariş kalmadı.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Masalara Dön'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
