import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/printer_model.dart';
import 'printer_controller.dart';

class PrinterScreen extends ConsumerStatefulWidget {
  const PrinterScreen({super.key});

  @override
  ConsumerState<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  void _showPrinterForm({Printer? existingPrinter}) {
    final isEditing = existingPrinter != null;
    final nameController = TextEditingController(text: existingPrinter?.name ?? '');
    final ipController = TextEditingController(text: existingPrinter?.ipAddress ?? '192.168.1.');
    final portController = TextEditingController(text: existingPrinter?.port.toString() ?? '9100');
    
    String? stationType = existingPrinter?.stationType;
    bool isCashier = existingPrinter?.isCashier ?? false;
    bool isSaving = false;
    bool isTesting = false;

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
                          isEditing ? 'Yazıcıyı Düzenle' : 'Yeni Yazıcı Ekle',
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

                    Text('Yazıcı Adı *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Örn: Mutfak Yazıcısı 1',
                        hintStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38)),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IP Adresi *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              TextField(
                                controller: ipController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Port *', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              TextField(
                                controller: portController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    Text('İstasyon (KDS / Mutfak vs.)', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: stationType,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          hint: Text('Bağlı Değil', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))),
                          items: [
                            DropdownMenuItem(value: null, child: Text('Hiçbiri', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'BAR', child: Text('Bar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'DESSERT', child: Text('Tatlı', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            DropdownMenuItem(value: 'COFFEE', child: Text('Kahve', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                          ],
                          onChanged: (val) {
                            setModalState(() => stationType = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Kasa / Müşteri Fişi Yazıcısı', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      subtitle: Text('Hesap ve ödeme fişleri buradan çıkar', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 12)),
                      value: isCashier,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setModalState(() => isCashier = val ?? false);
                      },
                    ),
                    
                    SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Theme.of(context).dividerColor),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isTesting
                                ? null
                                : () async {
                                    setModalState(() => isTesting = true);
                                    try {
                                      final ip = ipController.text.trim();
                                      final port = int.tryParse(portController.text.trim()) ?? 9100;
                                      
                                      final ok = await ref.read(printerServiceProvider).testPrinterConnection(ip, port);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Bağlantı Başarılı!' : 'Bağlantı Kurulamadı!'), 
                                            backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444)
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setModalState(() => isTesting = false);
                                    }
                                  },
                            child: isTesting 
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                                : Text('Test Et'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 2,
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
                                    final ip = ipController.text.trim();
                                    final port = int.tryParse(portController.text.trim()) ?? 9100;

                                    if (name.isEmpty || ip.isEmpty) return;

                                    setModalState(() => isSaving = true);
                                    try {
                                      final service = ref.read(printerServiceProvider);
                                      if (isEditing) {
                                        await service.updatePrinter(
                                          id: existingPrinter.id,
                                          name: name,
                                          ipAddress: ip,
                                          port: port,
                                          stationType: stationType,
                                          isCashier: isCashier,
                                        );
                                      } else {
                                        await service.createPrinter(
                                          name: name,
                                          ipAddress: ip,
                                          port: port,
                                          stationType: stationType,
                                          isCashier: isCashier,
                                        );
                                      }

                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        ref.invalidate(printersFutureProvider);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setModalState(() => isSaving = false);
                                    }
                                  },
                            child: isSaving
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2))
                                : Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  void _confirmDelete(Printer printer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Yazıcıyı Sil', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('${printer.name} kalıcı olarak kaldırılacak. Emin misiniz?', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
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
                await ref.read(printerServiceProvider).deletePrinter(printer.id);
                ref.invalidate(printersFutureProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            child: Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printersAsync = ref.watch(printersFutureProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Yazıcı Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
            onPressed: () => ref.invalidate(printersFutureProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPrinterForm(),
        backgroundColor: const Color(0xFF38BDF8),
        icon: Icon(Icons.print, color: Theme.of(context).colorScheme.onSurface),
        label: Text('Yeni Yazıcı', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ),
      body: printersAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, _) => Center(child: Text('Hata: $err', style: TextStyle(color: Colors.redAccent))),
        data: (printers) {
          if (printers.isEmpty) {
            return Center(child: Text('Kayıtlı yazıcı bulunamadı.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))));
          }

          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: printers.length,
            separatorBuilder: (_, _) => SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final printer = printers[idx];
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: Icon(Icons.print, color: Color(0xFF38BDF8)),
                  ),
                  title: Text(printer.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text('IP: ${printer.ipAddress}:${printer.port}', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13)),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (printer.stationType != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(51),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                printer.stationType!,
                                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (printer.isCashier)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(51),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'KASA',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      )
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54)),
                        onPressed: () => _showPrinterForm(existingPrinter: printer),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        onPressed: () => _confirmDelete(printer),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
