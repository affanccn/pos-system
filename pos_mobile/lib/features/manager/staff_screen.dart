import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/permissions.dart';
import '../../data/models/staff_model.dart';
import 'staff_controller.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return const Color(0xFF8B5CF6);
      case 'MANAGER':
        return const Color(0xFF38BDF8);
      case 'WAITER':
        return const Color(0xFF10B981);
      case 'KITCHEN':
        return const Color(0xFFF59E0B);
      default:
        return (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey);
    }
  }

  final Map<String, List<Map<String, String>>> _permissionGroups = {
    'Masa İşlemleri': [
      {'val': AppPermissions.tableView, 'label': 'Masa Görüntüleme'},
      {'val': AppPermissions.tableCreate, 'label': 'Masa Ekleme'},
      {'val': AppPermissions.tableEdit, 'label': 'Masa Düzenleme'},
      {'val': AppPermissions.tableDelete, 'label': 'Masa Silme'},
      {'val': AppPermissions.tableTransfer, 'label': 'Masa Transfer'},
      {'val': AppPermissions.tableMerge, 'label': 'Masa Birleştirme'},
      {'val': AppPermissions.tableSplit, 'label': 'Masa Bölme'},
    ],
    'Sipariş İşlemleri': [
      {'val': AppPermissions.orderCreate, 'label': 'Sipariş Oluşturma'},
      {'val': AppPermissions.orderEdit, 'label': 'Sipariş Düzenleme'},
      {'val': AppPermissions.orderCancel, 'label': 'Sipariş İptali'},
      {'val': AppPermissions.orderVoid, 'label': 'İade (Void)'},
      {'val': AppPermissions.orderDiscount, 'label': 'İndirim Uygulama'},
      {'val': AppPermissions.orderComplimentary, 'label': 'İkram Verme'},
    ],
    'Ödeme İşlemleri': [
      {'val': AppPermissions.paymentCreate, 'label': 'Ödeme Alma'},
      {'val': AppPermissions.paymentRefund, 'label': 'Para İadesi'},
      {'val': AppPermissions.paymentSplit, 'label': 'Parçalı Ödeme'},
    ],
    'Personel & Yönetim': [
      {'val': AppPermissions.staffView, 'label': 'Personel Görme'},
      {'val': AppPermissions.staffCreate, 'label': 'Personel Ekleme'},
      {'val': AppPermissions.staffEdit, 'label': 'Personel Düzenleme'},
      {'val': AppPermissions.staffDelete, 'label': 'Personel Silme'},
      {'val': AppPermissions.reportView, 'label': 'Rapor Görme'},
      {'val': AppPermissions.reportFinancial, 'label': 'Finansal Raporlar'},
      {'val': AppPermissions.settingsView, 'label': 'Ayarlar Görme'},
    ],
    'Menü & Mutfak': [
      {'val': AppPermissions.productView, 'label': 'Ürün Görme'},
      {'val': AppPermissions.productCreate, 'label': 'Ürün Ekleme'},
      {'val': AppPermissions.productEdit, 'label': 'Ürün Düzenleme'},
      {'val': AppPermissions.productPriceEdit, 'label': 'Fiyat Değiştirme'},
      {'val': AppPermissions.kitchenView, 'label': 'KDS Görme'},
      {'val': AppPermissions.kitchenManage, 'label': 'KDS Yönetimi'},
    ]
  };

  Widget _buildPermissionsSelector(List<String> selected, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Özel Yetkiler (İsteğe Bağlı)', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: _permissionGroups.entries.map((group) {
              return ExpansionTile(
                iconColor: const Color(0xFF38BDF8),
                collapsedIconColor: Colors.white54,
                title: Text(group.key, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                children: group.value.map((perm) {
                  final val = perm['val']!;
                  final label = perm['label']!;
                  final isChecked = selected.contains(val);
                  return CheckboxListTile(
                    title: Text(label, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13)),
                    value: isChecked,
                    activeColor: const Color(0xFF10B981),
                    checkColor: Colors.white,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    onChanged: (checked) {
                      setModalState(() {
                        if (checked == true) {
                          selected.add(val);
                        } else {
                          selected.remove(val);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAddStaffModal() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final pinController = TextEditingController();
    String selectedRole = 'WAITER';
    List<String> selectedPermissions = [];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
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
                          'Yeni Personel Tanımla',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    SizedBox(height: 12),

                    Text('Ad Soyad *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Örn: Ahmet Yılmaz',
                        hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38)),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),

                    Text('Görevi / Rolü *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          items: [
                            DropdownMenuItem(value: 'WAITER', child: Text('Garson (Masa & Sipariş)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak (KDS)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'MANAGER', child: Text('Müdür (Operasyon & Rapor)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'OWNER', child: Text('Patron (Tam Yetki)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    Text('4 Haneli Giriş PIN Kodu *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38)),
                        counterText: '',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),

                    Text('E-posta (İsteğe Bağlı)', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'ahmet@restoran.com',
                        hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38)),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildPermissionsSelector(selectedPermissions, setModalState),
                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final pin = pinController.text.trim();
                                final email = emailController.text.trim();

                                if (name.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lütfen geçerli bir ad girin.'), backgroundColor: Color(0xFFEF4444)),
                                  );
                                  return;
                                }

                                if (pin.length != 4) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('PIN tam 4 haneli rakam olmalıdır.'), backgroundColor: Color(0xFFEF4444)),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                try {
                                  await ref.read(staffServiceProvider).createStaff(
                                    fullName: name,
                                    pinCode: pin,
                                    role: selectedRole,
                                    email: email.isNotEmpty ? email : null,
                                    customPermissions: selectedPermissions.isNotEmpty ? selectedPermissions : null,
                                  );

                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    ref.invalidate(staffListProvider);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$name başarıyla kaydedildi!'), backgroundColor: const Color(0xFF10B981)),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                            : Text('Personeli Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showChangePinDialog(StaffUser staff) {
    final pinController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            '${staff.fullName} • PIN Değiştir',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yeni 4 haneli PIN belirleyin:', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13)),
              SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38)),
                  counterText: '',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Vazgeç', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPin = pinController.text.trim();
                      if (newPin.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN 4 hane olmalı.'), backgroundColor: Color(0xFFEF4444)),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(staffServiceProvider).updateStaffPin(
                          id: staff.id,
                          newPin: newPin,
                        );
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${staff.fullName} için PIN güncellendi!'), backgroundColor: const Color(0xFF10B981)),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                          );
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                  : Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffModal(StaffUser staff) {
    final nameController = TextEditingController(text: staff.fullName);
    final emailController = TextEditingController(text: staff.email ?? '');
    String selectedRole = staff.role;
    List<String> selectedPermissions = List.from(staff.customPermissions);
    bool isActive = staff.isActive;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
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
                          'Personel Bilgilerini Düzenle',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    SizedBox(height: 12),

                    Text('Ad Soyad', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),

                    Text('Görevi / Rolü', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          items: [
                            DropdownMenuItem(value: 'WAITER', child: Text('Garson', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'MANAGER', child: Text('Müdür', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'OWNER', child: Text('Patron', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hesap Durumu (Aktif)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                        Switch(
                          value: isActive,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) => setModalState(() => isActive = val),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    Text('E-posta', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildPermissionsSelector(selectedPermissions, setModalState),
                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.length < 2) return;

                                setModalState(() => isSaving = true);
                                try {
                                  await ref.read(staffServiceProvider).updateStaff(
                                    id: staff.id,
                                    fullName: name,
                                    role: selectedRole,
                                    email: emailController.text.trim(),
                                    isActive: isActive,
                                    customPermissions: selectedPermissions,
                                  );

                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    ref.invalidate(staffListProvider);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bilgiler güncellendi!'), backgroundColor: Color(0xFF10B981)),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                            : Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _confirmDeleteStaff(StaffUser staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Personeli Sil / Pasife Al', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          '${staff.fullName} adlı personelin hesabını kaldırmak istediğinize emin misiniz? (Geçmiş siparişi varsa pasife alınır)',
          style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Vazgeç', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(staffServiceProvider).deleteStaff(staff.id);
                ref.invalidate(staffListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${staff.fullName} işlem tamamlandı.'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            child: Text('Sil / Pasife Al'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Personel Yönetimi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: Icon(Icons.refresh, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
            onPressed: () => ref.invalidate(staffListProvider),
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              SizedBox(height: 12),
              Text('Hata: $err', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(staffListProvider),
                child: Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Text('Kayıtlı personel bulunamadı.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
            );
          }

          final activeCount = staffList.where((s) => s.isActive).length;
          final passiveCount = staffList.length - activeCount;

          return Column(
            children: [
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Toplam', '${staffList.length}', const Color(0xFF38BDF8)),
                    _buildStatCard('Aktif', '$activeCount', const Color(0xFF10B981)),
                    _buildStatCard('Pasif', '$passiveCount', const Color(0xFFEF4444)),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: staffList.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    final roleColor = _getRoleColor(staff.role);
                    final formattedDate = staff.createdAt != null
                        ? DateFormat('dd.MM.yyyy').format(staff.createdAt!)
                        : '-';

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: staff.isActive ? Theme.of(context).dividerColor : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          radius: 22,
                          child: Icon(
                            staff.role == 'KITCHEN' ? Icons.soup_kitchen : Icons.person,
                            color: roleColor,
                          ),
                        ),
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              staff.fullName,
                              style: TextStyle(
                                color: staff.isActive ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: roleColor, width: 1),
                              ),
                              child: Text(
                                AppRoles.getRoleLabel(staff.role),
                                style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (!staff.isActive)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Pasif',
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            if (staff.email != null && staff.email!.isNotEmpty)
                              Text(staff.email!, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 12)),
                            Text('Kayıt: $formattedDate', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            switch (val) {
                              case 'pin':
                                _showChangePinDialog(staff);
                                break;
                              case 'edit':
                                _showEditStaffModal(staff);
                                break;
                              case 'delete':
                                _confirmDeleteStaff(staff);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(Icons.pin, color: Color(0xFF38BDF8), size: 18),
                                  SizedBox(width: 8),
                                  Text('PIN Değiştir', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Color(0xFFF59E0B), size: 18),
                                  SizedBox(width: 8),
                                  Text('Düzenle', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                  SizedBox(width: 8),
                                  Text('Sil / Pasife Al', style: TextStyle(color: Color(0xFFEF4444))),
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
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: Icon(Icons.person_add),
        label: Text('Yeni Personel', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStaffModal,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 12, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
      ],
    );
  }
}
