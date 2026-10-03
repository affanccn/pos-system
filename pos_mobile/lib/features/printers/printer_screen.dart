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
                          isEditing ? 'Yazıcıyı Düzenle' : 'Yeni Yazıcı Ekle',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // İsim
                    const Text('Yazıcı Adı *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Örn: Mutfak Yazıcısı 1',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // IP ve Port
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('IP Adresi *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: ipController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Port *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: portController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // İstasyon Seçimi
                    const Text('İstasyon (KDS / Mutfak vs.)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: stationType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          hint: const Text('Bağlı Değil', style: TextStyle(color: Colors.white54)),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Hiçbiri', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'KITCHEN', child: Text('Mutfak', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'BAR', child: Text('Bar', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'DESSERT', child: Text('Tatlı', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'COFFEE', child: Text('Kahve', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            setModalState(() => stationType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kasa Yazıcısı mı?
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kasa / Müşteri Fişi Yazıcısı', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Hesap ve ödeme fişleri buradan çıkar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      value: isCashier,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setModalState(() => isCashier = val ?? false);
                      },
                    ),
                    
                    const SizedBox(height: 24),

                    // Butonlar
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Test Et'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
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
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Yazıcıyı Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('${printer.name} kalıcı olarak kaldırılacak. Emin misiniz?', style: const TextStyle(color: Colors.white70)),
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
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printersAsync = ref.watch(printersFutureProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Yazıcı Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => ref.invalidate(printersFutureProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPrinterForm(),
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text('Yeni Yazıcı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: printersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.redAccent))),
        data: (printers) {
          if (printers.isEmpty) {
            return const Center(child: Text('Kayıtlı yazıcı bulunamadı.', style: TextStyle(color: Colors.white54)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: printers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, idx) {
              final printer = printers[idx];
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0F172A),
                    child: Icon(Icons.print, color: Color(0xFF38BDF8)),
                  ),
                  title: Text(printer.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('IP: ${printer.ipAddress}:${printer.port}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (printer.stationType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(51),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                printer.stationType!,
                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (printer.isCashier)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(51),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
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
                        icon: const Icon(Icons.edit, color: Colors.white54),
                        onPressed: () => _showPrinterForm(existingPrinter: printer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
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
