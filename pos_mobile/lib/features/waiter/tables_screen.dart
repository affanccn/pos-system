import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../core/auth/permissions.dart';
import '../../core/widgets/app_states.dart';
import '../../core/network/socket_service.dart';
import '../../data/models/table_model.dart';
import '../auth/auth_controller.dart';
import 'tables_controller.dart';
import '../../main.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  Widget _buildBottomBarButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTableUpdated(dynamic _) {
    if (mounted) {
      ref.invalidate(tablesFutureProvider);
    }
  }

  void _onItemReady(dynamic data) {
    if (!mounted) return;
    final tableName = data['tableName'] ?? 'Masa';
    final productName = data['productName'] ?? 'Ürün';
    final qty = data['quantity'] ?? 1;

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.onSurface),
            SizedBox(width: 8),
            Expanded(
              child: Text('🔔 $tableName: $qty adet $productName HAZIR!'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onAllReady(dynamic data) {
    if (!mounted) return;
    final tableName = data['tableName'] ?? 'Masa';

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onSurface),
            SizedBox(width: 8),
            Expanded(child: Text('✅ $tableName siparişinin TÜMÜ hazır!')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final socketService = ref.read(socketServiceProvider);
        final dynamic s = socketService;
        final rawSocket = s.socket ?? s.client ?? s.io;

        rawSocket?.on('table:updated', _onTableUpdated);
        rawSocket?.on('order:item_ready', _onItemReady);
        rawSocket?.on('order:all_ready', _onAllReady);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    try {
      final socketService = ref.read(socketServiceProvider);
      final dynamic s = socketService;
      final rawSocket = s.socket ?? s.client ?? s.io;

      rawSocket?.off('table:updated', _onTableUpdated);
      rawSocket?.off('order:item_ready', _onItemReady);
      rawSocket?.off('order:all_ready', _onAllReady);
    } catch (_) {}
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AVAILABLE':
        return const Color(0xFF10B981);
      case 'OCCUPIED':
        return const Color(0xFFEF4444);
      case 'BILL_REQUESTED':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Boş';
      case 'OCCUPIED':
        return 'Dolu';
      case 'BILL_REQUESTED':
        return 'Hesap İstendi';
      default:
        return 'Bilinmiyor';
    }
  }

  void _confirmLogout(BuildContext context) {
    showAppDialog(
      context: context,
      title: 'Oturumu Kapat',
      content: Text(
        'Mevcut kullanıcı oturumunu kapatıp PIN ekranına dönmek istiyor musunuz?',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
      confirmText: 'Çıkış Yap',
      isDestructive: true,
      onConfirm: () {
        Navigator.of(context).pop();
        ref.read(authProvider).logout();
      },
    );
  }

  void _showTableFormDialog({RestaurantTable? existingTable}) {
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = existingTable != null;
    final nameController = TextEditingController(
      text: isEditing ? existingTable.displayName : '',
    );
    int capacity = isEditing ? existingTable.capacity : 4;
    String selectedSection = isEditing ? existingTable.section : 'Salon';
    final sections = ['Salon', 'Teras', 'Bahçe', 'VIP'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            isEditing ? 'Masayı Düzenle' : 'Yeni Masa Ekle',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masa Adı / Numarası',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Örn: Masa 12',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Bölüm / Salon',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sections.map((sec) {
                    final isSel = selectedSection == sec;
                    return ChoiceChip(
                      label: Text(sec),
                      selected: isSel,
                      selectedColor: const Color(0xFF38BDF8)
                          .withValues(alpha: 0.25),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      labelStyle: TextStyle(
                        color: isSel ? const Color(0xFF38BDF8) : Colors.white70,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSel
                            ? const Color(0xFF38BDF8)
                            : Theme.of(context).dividerColor,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedSection = sec);
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                Text(
                  'Kapasite (Kişi Sayısı)',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFF38BDF8),
                      ),
                      onPressed: capacity > 1
                          ? () => setDialogState(() => capacity--)
                          : null,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        '$capacity Kişi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF38BDF8),
                      ),
                      onPressed: () => setDialogState(() => capacity++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Vazgeç',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Lütfen masa adını girin.')),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                try {
                  final ops = ref.read(tableOperationsProvider);
                  if (isEditing) {
                    await ops.updateTable(
                      id: existingTable.id,
                      name: name,
                      section: selectedSection,
                      capacity: capacity,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('$name masası güncellendi.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } else {
                    await ops.createTable(
                      name: name,
                      section: selectedSection,
                      capacity: capacity,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('$name masası başarıyla eklendi.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('İşlem başarısız: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableActionSheet(RestaurantTable table) {
    final userState = ref.read(authProvider).state;
    final canEdit = userState.hasPermission(AppPermissions.tableEdit);
    final canDelete = userState.hasPermission(AppPermissions.tableDelete);

    if (!canEdit && !canDelete) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${table.name} İşlemleri',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Divider(color: Theme.of(context).dividerColor),
            if (canEdit)
              ListTile(
                leading: Icon(Icons.edit, color: Color(0xFF38BDF8)),
                title: Text(
                  'Masayı Düzenle',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: Text(
                  'İsim, kapasite ve bölümü değiştir',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showTableFormDialog(existingTable: table);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                ),
                title: Text(
                  'Masayı Sil',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
                subtitle: Text(
                  table.status != 'AVAILABLE'
                      ? 'Dolu masa silinemez! Önce hesabı kapatın.'
                      : 'Masayı sistemden kaldır',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                enabled: table.status == 'AVAILABLE',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteTable(table);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTable(RestaurantTable table) {
    final messenger = ScaffoldMessenger.of(context);
    showAppDialog(
      context: context,
      title: 'Masayı Sil',
      content: Text(
        '${table.name} masası kalıcı olarak silinecek. Emin misiniz?',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
      confirmText: 'Sil',
      isDestructive: true,
      onConfirm: () async {
        Navigator.of(context).pop();
        try {
          await ref.read(tableOperationsProvider).deleteTable(table.id);
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('${table.name} silindi.'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Silme başarısız: $e'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesFutureProvider);
    final userState = ref.watch(authProvider).state;
    final selectedSection = ref.watch(selectedSectionProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masa Yönetimi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${userState.name ?? "Personel"} • ${AppRoles.getRoleLabel(userState.role)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
          if (userState.hasPermission(AppPermissions.kitchenView))
            IconButton(
              tooltip: 'Mutfak Ekranı',
              icon: Icon(
                Icons.soup_kitchen,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
              onPressed: () => context.push('/kitchen'),
            ),
          IconButton(
            tooltip: 'Yenile',
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: () => ref.invalidate(tablesFutureProvider),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
            onPressed: () => _confirmLogout(context),
          ),
        ],
        bottom:
            (userState.hasPermission(AppPermissions.reportView) ||
                userState.role == AppRoles.manager ||
                userState.role == AppRoles.owner)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(76),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (userState.hasPermission(
                              AppPermissions.reportView,
                            ))
                              _buildBottomBarButton(
                                Icons.analytics_outlined,
                                'Z Raporu',
                                const Color(0xFF38BDF8),
                                () => context.push('/reports/daily'),
                              ),
                            if (userState.hasPermission(
                              AppPermissions.reportView,
                            ))
                              _buildBottomBarButton(
                                Icons.query_stats,
                                'Raporlar',
                                const Color(0xFFF59E0B),
                                () => context.push('/reports/advanced'),
                              ),
                            if (userState.hasPermission(
                              AppPermissions.reportFinancial,
                            ))
                              _buildBottomBarButton(
                                Icons.trending_up,
                                'Kâr/Maliyet',
                                const Color(0xFF10B981),
                                () => context.push('/reports/profitability'),
                              ),
                            if (userState.hasPermission(
                              AppPermissions.staffView,
                            ))
                              _buildBottomBarButton(
                                Icons.people_alt_outlined,
                                'Personel',
                                const Color(0xFF8B5CF6),
                                () => context.push('/manager/staff'),
                              ),
                            if (userState.role == AppRoles.manager ||
                                userState.role == AppRoles.owner)
                              _buildBottomBarButton(
                                Icons.restaurant_menu,
                                'Menü',
                                const Color(0xFF10B981),
                                () => context.push('/manager/catalog'),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (userState.role == AppRoles.manager &&
                                userState.hasPermission(
                                  AppPermissions.settingsView,
                                ))
                              _buildBottomBarButton(
                                Icons.settings,
                                'Ayarlar',
                                const Color(0xFFF43F5E),
                                () => context.push('/settings'),
                              ),
                            if (userState.role == AppRoles.manager ||
                                userState.role == AppRoles.owner)
                              _buildBottomBarButton(
                                Icons.money_off,
                                'Giderler',
                                const Color(0xFFEF4444),
                                () => context.push('/manager/expenses'),
                              ),
                            if (userState.role == AppRoles.manager ||
                                userState.role == AppRoles.owner)
                              _buildBottomBarButton(
                                Icons.point_of_sale,
                                'Kasa',
                                const Color(0xFF14B8A6),
                                () => context.push('/manager/cash'),
                              ),
                            if (userState.role == AppRoles.owner)
                              _buildBottomBarButton(
                                Icons.history,
                                'Log',
                                const Color(0xFFA78BFA),
                                () => context.push('/manager/audit'),
                              ),
                            if (userState.role == AppRoles.manager ||
                                userState.role == AppRoles.owner ||
                                userState.hasPermission(
                                  AppPermissions.tableView,
                                ))
                              _buildBottomBarButton(
                                Icons.event_seat,
                                'Rezervasyon',
                                const Color(0xFF10B981),
                                () => context.push('/manager/reservations'),
                              ),
                            if (userState.role == AppRoles.owner)
                              _buildBottomBarButton(
                                Icons.storefront,
                                'Şubeler',
                                const Color(0xFFF59E0B),
                                () => context.push('/manager/branches'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: userState.hasPermission(AppPermissions.tableCreate)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
              icon: Icon(Icons.add),
              label: Text(
                'Yeni Masa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showTableFormDialog(),
            )
          : null,
      body: tablesAsync.when(
        loading: () => const AppLoadingState(message: 'Masalar yükleniyor...'),
        error: (err, _) => AppErrorState(
          message: 'Masalar yüklenirken hata oluştu:\n$err',
          onRetry: () => ref.invalidate(tablesFutureProvider),
        ),
        data: (tables) {
          if (tables.isEmpty) {
            return AppEmptyState(
              message: 'Henüz hiç masa eklenmemiş.',
              icon: Icons.table_restaurant,
              actionLabel: userState.hasPermission(AppPermissions.tableCreate)
                  ? 'Masa Ekle'
                  : null,
              onAction: userState.hasPermission(AppPermissions.tableCreate)
                  ? () => _showTableFormDialog()
                  : null,
            );
          }
          final dynamicSections = <String>{'Salon', 'Teras', 'Bahçe', 'VIP'};
          for (final t in tables) {
            dynamicSections.add(t.section);
          }
          final allSectionTabs = ['Tümü', ...dynamicSections];

          final filteredTables = selectedSection == 'Tümü'
              ? tables
              : tables
                    .where(
                      (t) =>
                          t.section.toLowerCase() ==
                          selectedSection.toLowerCase(),
                    )
                    .toList();

          return Column(
            children: [
              Container(
                height: 54,
                padding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: allSectionTabs.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sectionName = allSectionTabs[index];
                    final isSelected = selectedSection == sectionName;

                    final count = sectionName == 'Tümü'
                        ? tables.length
                        : tables
                              .where(
                                (t) =>
                                    t.section.toLowerCase() ==
                                    sectionName.toLowerCase(),
                              )
                              .length;

                    return InkWell(
                      onTap: () {
                        ref.read(selectedSectionProvider.notifier).state =
                            sectionName;
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              sectionName,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: filteredTables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_restaurant,
                              color: Color(0xFF64748B),
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '$selectedSection bölümünde masa bulunamadı.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableGridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.15,
                            ),
                        onReorder: (oldIndex, newIndex) {
                          final reorderedList = List<RestaurantTable>.from(
                            filteredTables,
                          );
                          final item = reorderedList.removeAt(oldIndex);
                          reorderedList.insert(newIndex, item);

                          final sortedOrders =
                              filteredTables.map((t) => t.sortOrder).toList()
                                ..sort();
                          final updates = <Map<String, dynamic>>[];
                          for (int i = 0; i < reorderedList.length; i++) {
                            updates.add({
                              'id': reorderedList[i].id,
                              'sortOrder': sortedOrders[i],
                            });
                          }
                          ref
                              .read(tableOperationsProvider)
                              .reorderTables(updates);
                        },
                        itemCount: filteredTables.length,
                        itemBuilder: (context, index) {
                          final table = filteredTables[index];
                          final statusColor = _getStatusColor(table.status);
                          final isAvailable = table.status == 'AVAILABLE';

                          return InkWell(
                            key: ValueKey(table.id),
                            onTap: () {
                              if (isAvailable) {
                                context
                                    .push('/waiter/order', extra: table)
                                    .then(
                                      (_) =>
                                          ref.invalidate(tablesFutureProvider),
                                    );
                              } else {
                                context
                                    .push('/waiter/table-detail', extra: table)
                                    .then(
                                      (_) =>
                                          ref.invalidate(tablesFutureProvider),
                                    );
                              }
                            },
                            onLongPress: () => _showTableActionSheet(table),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            table.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusText(table.status),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              color: Theme.of(context).textTheme.bodyMedium?.color,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '${table.capacity} Kişi',
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (userState.hasPermission(
                                                  AppPermissions.tableEdit,
                                                ) ||
                                                userState.hasPermission(
                                                  AppPermissions.tableDelete,
                                                ))
                                              IconButton(
                                                icon: Icon(
                                                  Icons.more_vert,
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _showTableActionSheet(
                                                      table,
                                                    ),
                                              ),
                                            SizedBox(width: 6),
                                            Icon(
                                              isAvailable
                                                  ? Icons.add_circle_outline
                                                  : Icons.receipt_long,
                                              color: statusColor,
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
