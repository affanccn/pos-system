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
        return const Color(0xFF94A3B8);
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
        const Text('Özel Yetkiler (İsteğe Bağlı)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: _permissionGroups.entries.map((group) {
              return ExpansionTile(
                iconColor: const Color(0xFF38BDF8),
                collapsedIconColor: Colors.white54,
                title: Text(group.key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                children: group.value.map((perm) {
                  final val = perm['val']!;
                  final label = perm['label']!;
                  final isChecked = selected.contains(val);
                  return CheckboxListTile(
                    title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    value: isChecked,
                    activeColor: const Color(0xFF10B981),
                    checkColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
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
                        const Text(
                          'Yeni Personel Tanımla',
                          style: TextStyle(
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
                    const SizedBox(height: 12),

                    const Text('Ad Soyad *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Örn: Ahmet Yılmaz',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Görevi / Rolü *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          items: const [
                            DropdownMenuItem(value: 'WAITER', child: Text('Garson (Masa & Sipariş)', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak (KDS)', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'MANAGER', child: Text('Müdür (Operasyon & Rapor)', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'OWNER', child: Text('Patron (Tam Yetki)', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('4 Haneli Giriş PIN Kodu *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(color: Colors.white38),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('E-posta (İsteğe Bağlı)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ahmet@restoran.com',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPermissionsSelector(selectedPermissions, setModalState),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Personeli Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            '${staff.fullName} • PIN Değiştir',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Yeni 4 haneli PIN belirleyin:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8))),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet'),
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
                        const Text(
                          'Personel Bilgilerini Düzenle',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    const Text('Ad Soyad', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Görevi / Rolü', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          items: const [
                            DropdownMenuItem(value: 'WAITER', child: Text('Garson', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'MANAGER', child: Text('Müdür', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'OWNER', child: Text('Patron', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hesap Durumu (Aktif)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        Switch(
                          value: isActive,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) => setModalState(() => isActive = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('E-posta', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPermissionsSelector(selectedPermissions, setModalState),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Personeli Sil / Pasife Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '${staff.fullName} adlı personelin hesabını kaldırmak istediğinize emin misiniz? (Geçmiş siparişi varsa pasife alınır)',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8))),
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
            child: const Text('Sil / Pasife Al'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Personel Yönetimi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => ref.invalidate(staffListProvider),
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text('Hata: $err', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(staffListProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (staffList) {
          if (staffList.isEmpty) {
            return const Center(
              child: Text('Kayıtlı personel bulunamadı.', style: TextStyle(color: Colors.white70)),
            );
          }

          final activeCount = staffList.where((s) => s.isActive).length;
          final passiveCount = staffList.length - activeCount;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: staffList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    final roleColor = _getRoleColor(staff.role);
                    final formattedDate = staff.createdAt != null
                        ? DateFormat('dd.MM.yyyy').format(staff.createdAt!)
                        : '-';

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: staff.isActive ? const Color(0xFF334155) : const Color(0xFF334155).withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Pasif',
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (staff.email != null && staff.email!.isNotEmpty)
                              Text(staff.email!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            Text('Kayıt: $formattedDate', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                          color: const Color(0xFF1E293B),
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
                            const PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(Icons.pin, color: Color(0xFF38BDF8), size: 18),
                                  SizedBox(width: 8),
                                  Text('PIN Değiştir', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Color(0xFFF59E0B), size: 18),
                                  SizedBox(width: 8),
                                  Text('Düzenle', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
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
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni Personel', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStaffModal,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }
}
