import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../core/auth/permissions.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authProvider).state;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1221),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Yönetici Paneli',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${userState.name ?? "Personel"} • ${AppRoles.getRoleLabel(userState.role)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background floating gradients
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.count(
                physics: const BouncingScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildDashboardCard(
                    context,
                    title: 'Masa Yönetimi',
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFF22D3EE),
                    onTap: () => context.push('/waiter/tables'),
                  ),
                  if (userState.hasPermission(AppPermissions.reportView))
                    _buildDashboardCard(
                      context,
                      title: 'Z Raporu',
                      icon: Icons.analytics_outlined,
                      color: const Color(0xFF38BDF8),
                      onTap: () => context.push('/reports/daily'),
                    ),
                  if (userState.hasPermission(AppPermissions.reportView))
                    _buildDashboardCard(
                      context,
                      title: 'Raporlar',
                      icon: Icons.query_stats,
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.push('/reports/advanced'),
                    ),
                  if (userState.hasPermission(AppPermissions.reportFinancial))
                    _buildDashboardCard(
                      context,
                      title: 'Kâr/Maliyet',
                      icon: Icons.trending_up,
                      color: const Color(0xFF10B981),
                      onTap: () => context.push('/reports/profitability'),
                    ),
                  if (userState.role == AppRoles.manager ||
                      userState.role == AppRoles.owner)
                    _buildDashboardCard(
                      context,
                      title: 'Kasa',
                      icon: Icons.point_of_sale,
                      color: const Color(0xFF14B8A6),
                      onTap: () => context.push('/manager/cash'),
                    ),
                  if (userState.role == AppRoles.manager ||
                      userState.role == AppRoles.owner)
                    _buildDashboardCard(
                      context,
                      title: 'Giderler',
                      icon: Icons.money_off,
                      color: const Color(0xFFEF4444),
                      onTap: () => context.push('/manager/expenses'),
                    ),
                  if (userState.role == AppRoles.manager ||
                      userState.role == AppRoles.owner)
                    _buildDashboardCard(
                      context,
                      title: 'Menü',
                      icon: Icons.restaurant_menu,
                      color: const Color(0xFF10B981),
                      onTap: () => context.push('/manager/catalog'),
                    ),
                  if (userState.hasPermission(AppPermissions.staffView))
                    _buildDashboardCard(
                      context,
                      title: 'Personel',
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.push('/manager/staff'),
                    ),
                  if (userState.role == AppRoles.manager ||
                      userState.role == AppRoles.owner ||
                      userState.hasPermission(AppPermissions.tableView))
                    _buildDashboardCard(
                      context,
                      title: 'Rezervasyon',
                      icon: Icons.event_seat,
                      color: const Color(0xFF10B981),
                      onTap: () => context.push('/manager/reservations'),
                    ),
                  if (userState.role == AppRoles.owner)
                    _buildDashboardCard(
                      context,
                      title: 'Şubeler',
                      icon: Icons.store,
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.push('/manager/branches'),
                    ),
                  if (userState.role == AppRoles.owner)
                    _buildDashboardCard(
                      context,
                      title: 'Log',
                      icon: Icons.history,
                      color: const Color(0xFFA78BFA),
                      onTap: () => context.push('/manager/audit'),
                    ),
                  if (userState.role == AppRoles.manager &&
                      userState.hasPermission(AppPermissions.settingsView))
                    _buildDashboardCard(
                      context,
                      title: 'Ayarlar',
                      icon: Icons.settings,
                      color: const Color(0xFFF43F5E),
                      onTap: () => context.push('/settings'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (result == true) {
      ref.read(authProvider.notifier).logout();
    }
  }
}
