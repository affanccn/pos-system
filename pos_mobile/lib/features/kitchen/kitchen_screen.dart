import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../../core/network/socket_service.dart';
import '../../core/widgets/app_states.dart';
import '../../main.dart';

final kitchenOrdersProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.dio.get('/orders/kitchen');
    return (response.data['data'] as List<dynamic>?) ?? [];
  } catch (e) {
    throw Exception('Mutfak siparişleri yüklenemedi: $e');
  }
});

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _refreshTimer;
  String _selectedStation = 'ALL';

  void _onOrderUpdate(dynamic _) {
    if (mounted) ref.invalidate(kitchenOrdersProvider);
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final socketService = ref.read(socketServiceProvider);
        final dynamic s = socketService;
        final rawSocket = s.socket ?? s.client ?? s.io;

        rawSocket?.on('order:created', _onOrderUpdate);
        rawSocket?.on('order:items_added', _onOrderUpdate);
        rawSocket?.on('kitchen:item_updated', _onOrderUpdate);
        rawSocket?.on('kitchen:order_completed', _onOrderUpdate);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    try {
      final socketService = ref.read(socketServiceProvider);
      final dynamic s = socketService;
      final rawSocket = s.socket ?? s.client ?? s.io;
      
      rawSocket?.off('order:created', _onOrderUpdate);
      rawSocket?.off('order:items_added', _onOrderUpdate);
      rawSocket?.off('kitchen:item_updated', _onOrderUpdate);
      rawSocket?.off('kitchen:order_completed', _onOrderUpdate);
    } catch (_) {}
    
    super.dispose();
  }

  Future<void> _updateItemStatus(String itemId, String currentStatus) async {
    String nextStatus = 'PREPARING';
    if (currentStatus == 'PENDING') {
      nextStatus = 'PREPARING';
    } else if (currentStatus == 'PREPARING') {
      nextStatus = 'READY';
    } else {
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.patch(
        '/orders/items/$itemId/status',
        data: {'status': nextStatus},
      );

      if (response.statusCode == 200 && mounted) {
        ref.invalidate(kitchenOrdersProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum güncellenemedi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _readyAll(String orderId, String tableName) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.patch('/orders/$orderId/ready-all');

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$tableName siparişi tamamlandı ve servise gönderildi!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        ref.invalidate(kitchenOrdersProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sipariş tamamlanamadı: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  int _getMinutesElapsed(String? createdAtStr) {
    if (createdAtStr == null) return 0;
    try {
      final createdAt = DateTime.parse(createdAtStr);
      return DateTime.now().difference(createdAt).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  bool _matchesStation(dynamic item) {
    if (_selectedStation == 'ALL') return true;
    final stationType =
        item['product']?['category']?['stationType'] ?? 'KITCHEN';
    return stationType == _selectedStation;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(Icons.soup_kitchen, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mutfak & Bar Ekranı (KDS)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Temayı Değiştir',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.amber : Colors.indigo,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: Icon(Icons.refresh, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
            onPressed: () => ref.invalidate(kitchenOrdersProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildStationChip(
                    'Tüm Siparişler',
                    'ALL',
                    Icons.all_inclusive,
                  ),
                  SizedBox(width: 8),
                  _buildStationChip('Mutfak', 'KITCHEN', Icons.restaurant),
                  SizedBox(width: 8),
                  _buildStationChip('Bar / İçecek', 'BAR', Icons.local_bar),
                  SizedBox(width: 8),
                  _buildStationChip('Tatlı', 'DESSERT', Icons.cake),
                  SizedBox(width: 8),
                  _buildStationChip('Kahve', 'COFFEE', Icons.coffee),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ordersAsync.when(
        loading: () => const AppLoadingState(message: 'Siparişler yükleniyor...'),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              SizedBox(height: 12),
              Text('Hata: $err', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(kitchenOrdersProvider),
                child: Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (orders) {
          final filteredOrders = orders
              .map((order) {
                final items = (order['items'] as List<dynamic>?) ?? [];
                final stationItems = items.where(_matchesStation).toList();
                return {...order, 'displayItems': stationItems};
              })
              .where((order) {
                final displayItems = order['displayItems'] as List<dynamic>;
                return displayItems.isNotEmpty;
              })
              .toList();

          if (filteredOrders.isEmpty) {
            return const AppEmptyState(
              message: 'Şu an bekleyen sipariş yok.',
              icon: Icons.check_circle_outline,
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : (constraints.maxWidth > 600 ? 2 : 1);

              return GridView.builder(
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  final orderId = order['id'] as String;
                  final tableName = order['table']?['name'] ?? 'Masa';
                  final waiterName = order['waiter']?['fullName'] ?? 'Garson';
                  final orderNumber = order['orderNumber'] ?? '-';
                  final notes = order['notes'];
                  final items = order['displayItems'] as List<dynamic>;
                  final elapsedMins = _getMinutesElapsed(order['createdAt']);

                  Color timerColor = const Color(0xFF10B981);
                  if (elapsedMins >= 15) {
                    timerColor = const Color(0xFFEF4444);
                  } else if (elapsedMins >= 8) {
                    timerColor = const Color(0xFFF59E0B);
                  }

                  final bool allReady = items.every(
                    (i) => i['status'] == 'READY',
                  );

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: allReady
                            ? const Color(0xFF10B981)
                            : (elapsedMins >= 15
                                  ? const Color(0xFFEF4444)
                                  : Theme.of(context).dividerColor),
                        width: allReady || elapsedMins >= 15 ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tableName,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '#$orderNumber • $waiterName',
                                    style: TextStyle(
                                      color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: timerColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: timerColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: timerColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '$elapsedMins dk',
                                      style: TextStyle(
                                        color: timerColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (notes != null && notes.toString().isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Not: $notes',
                                    style: TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.all(12),
                            itemCount: items.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Theme.of(context).dividerColor,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final itemId = item['id'] as String;
                              final name = item['productNameSnapshot'] ?? 'Ürün';
                              final qty = item['quantity'] ?? 1;
                              final itemNotes = item['notes'];
                              final modifiers = (item['modifiers'] as List<dynamic>?) ?? [];
                              final status = item['status'] ?? 'PENDING';

                              Color statusColor = const Color(0xFFEF4444);
                              String statusText = 'Bekliyor';
                              IconData statusIcon = Icons.hourglass_empty;

                              if (status == 'PREPARING') {
                                statusColor = const Color(0xFFF59E0B);
                                statusText = 'Hazırlanıyor';
                                statusIcon = Icons.outdoor_grill;
                              } else if (status == 'READY') {
                                statusColor = const Color(0xFF10B981);
                                statusText = 'Hazır';
                                statusIcon = Icons.check_circle;
                              }

                              return InkWell(
                                onTap: status == 'READY'
                                    ? null
                                    : () => _updateItemStatus(itemId, status),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFF0F172A,
                                        ),
                                        radius: 14,
                                        child: Text(
                                          '$qty',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: status == 'READY'
                                                    ? Colors.white38
                                                    : Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                decoration: status == 'READY'
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            if (modifiers.isNotEmpty)
                                              ...modifiers.map((mod) => Text(
                                                '+ ${mod['modifierNameSnapshot']} ${mod['quantity'] > 1 ? '(x${mod['quantity']})' : ''}',
                                                style: TextStyle(
                                                  color: status == 'READY' ? Colors.white38 : const Color(0xFF38BDF8),
                                                  fontSize: 12,
                                                  decoration: status == 'READY' ? TextDecoration.lineThrough : null,
                                                ),
                                              )),
                                            if (itemNotes != null &&
                                                itemNotes.toString().isNotEmpty)
                                              Text(
                                                '• $itemNotes',
                                                style: TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              statusIcon,
                                              size: 14,
                                              color: statusColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.all(10),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allReady
                                  ? const Color(0xFF10B981)
                                  : Theme.of(context).dividerColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              allReady ? Icons.send : Icons.done_all,
                              size: 18,
                            ),
                            label: Text(
                              allReady
                                  ? 'Servise Gönder / Arşivle'
                                  : 'Tümünü Hazırla & Gönder',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () => _readyAll(orderId, tableName),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStationChip(String title, String stationKey, IconData icon) {
    final isSelected = _selectedStation == stationKey;
    return InkWell(
      onTap: () => setState(() => _selectedStation = stationKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.black
                    : const Color.fromRGBO(255, 255, 255, 0.702),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
