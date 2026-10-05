import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../../core/auth/permissions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, Color iconColor) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authProvider).state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Ayarlar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (userState.role == AppRoles.owner || userState.role == AppRoles.manager)
            _buildSettingsTile(
              context,
              Icons.storefront,
              'Restoran Bilgileri',
              'Şube adı, logo, iletişim, adres',
              () {},
              const Color(0xFF38BDF8),
            ),
          
          if (userState.hasPermission(AppPermissions.settingsView) == true)
            _buildSettingsTile(
              context,
              Icons.grid_view,
              'Salon & Masalar',
              'Salon yönetimi, masa düzeni, kapasiteler',
              () {},
              const Color(0xFF10B981),
            ),

          if (userState.hasPermission(AppPermissions.productView) == true)
            _buildSettingsTile(
              context,
              Icons.menu_book,
              'Menü & Katalog',
              'Kategoriler, ürünler, içerikler',
              () => context.push('/manager/catalog'),
              const Color(0xFFF59E0B),
            ),

          if (userState.hasPermission(AppPermissions.settingsView) == true)
            _buildSettingsTile(
              context,
              Icons.print,
              'Yazıcılar',
              'İstasyon yazıcıları, fiş ayarları, ağ yapılandırması',
              () => context.push('/settings/printers'),
              const Color(0xFFF43F5E),
            ),

          if (userState.hasPermission(AppPermissions.settingsView) == true)
            _buildSettingsTile(
              context,
              Icons.people,
              'Personel & Yetkiler',
              'Çalışanlar, roller, erişim izinleri',
              () {},
              const Color(0xFFA78BFA),
            ),

          _buildSettingsTile(
            context,
            Icons.settings_system_daydream,
            'Sistem Ayarları',
            'Tema, ses, bildirimler, haptic',
            () {},
            (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
          ),
        ],
      ),
    );
  }
}
