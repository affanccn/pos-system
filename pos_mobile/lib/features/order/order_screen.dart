import 'package:flutter/material.dart';
import '../../data/models/catalog_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_model.dart';
import '../auth/auth_controller.dart';
import 'order_controller.dart';
import '../waiter/tables_controller.dart';

class OrderScreen extends ConsumerStatefulWidget {
  final RestaurantTable table;
  final String? existingOrderId;

  const OrderScreen({
    super.key,
    required this.table,
    this.existingOrderId,
  });

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      final payloadItems = cart.items.map((item) {
        return {
          'productId': item.product.id,
          'quantity': item.quantity,
          'notes': item.note,
          'modifiers': item.modifiers.map((m) => {
            'modifierItemId': m.id,
            'quantity': 1,
          }).toList(),
        };
      }).toList();

      if (widget.existingOrderId != null) {
        final response = await apiClient.dio.post(
          '/orders/${widget.existingOrderId}/items',
          data: {
            'items': payloadItems,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          cart.clearCart();
          if (mounted) {
            ref.invalidate(tablesFutureProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ürünler başarıyla adisyona eklendi!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            Navigator.of(context).pop();
          }
        }
      } else {
        final response = await apiClient.dio.post(
          '/orders',
          data: {
            'tableId': widget.table.id,
            'items': payloadItems,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          cart.clearCart();
          if (mounted) {
            ref.invalidate(tablesFutureProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sipariş başarıyla oluşturuldu!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            Navigator.of(context).pop();
          }
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showItemNoteDialog(int index, CartItem item) {
    final noteController = TextEditingController(text: item.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('${item.product.name} Notu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Örn: Az şekerli, sossuz, buzsuz...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
            onPressed: () {
              final newNote = noteController.text.trim();
              ref.read(cartProvider).updateNote(index, newNote.isEmpty ? null : newNote);
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final cart = ref.watch(cartProvider);

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.70,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.existingOrderId != null ? 'Eklenecek Ürünler' : 'Masa Sepeti',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155)),
                  Expanded(
                    child: cart.isEmpty
                        ? const Center(
                            child: Text('Sepet henüz boş', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.separated(
                            itemCount: cart.items.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155)),
                            itemBuilder: (context, index) {
                              final item = cart.items[index];
                              final modNames = item.modifiers.map((m) => m.name).join(', ');

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (modNames.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '+ $modNames',
                                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                                        ),
                                      ),
                                    if (item.note != null && item.note!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Not: ${item.note}',
                                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.unitPrice.toStringAsFixed(2)} ₺ x ${item.quantity} = ${item.total.toStringAsFixed(2)} ₺',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Not / Açıklama Ekle',
                                      icon: Icon(
                                        item.note != null && item.note!.isNotEmpty ? Icons.note : Icons.note_add_outlined,
                                        color: item.note != null && item.note!.isNotEmpty ? const Color(0xFFF59E0B) : Colors.white38,
                                        size: 20,
                                      ),
                                      onPressed: () => _showItemNoteDialog(index, item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                                      onPressed: () => cart.removeProductAt(index),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                                      onPressed: () => cart.addProductAt(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Color(0xFF334155)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam Tutar:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(
                        '${cart.totalPrice.toStringAsFixed(2)} ₺',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: cart.isEmpty || _isSubmitting
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _submitOrder();
                            },
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.existingOrderId != null ? 'Adisyona Ekle' : 'Siparişi Onayla',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showModifierModal(BuildContext context, Product product, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final Set<String> selectedModifierIds = {};
        final noteController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            double currentPrice = product.price;
            final selectedModifiersList = <ProductModifierItem>[];
            for (var group in product.modifierGroups) {
              for (var item in group.items) {
                if (selectedModifierIds.contains(item.id)) {
                  currentPrice += item.priceCents / 100.0;
                  selectedModifiersList.add(item);
                }
              }
            }

            bool isValid = true;
            for (var group in product.modifierGroups) {
              int selectedCount = 0;
              for (var item in group.items) {
                if (selectedModifierIds.contains(item.id)) selectedCount++;
              }
              if (group.isRequired && selectedCount < group.minSelect) {
                isValid = false;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.80,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.modifierGroups.isNotEmpty)
                              ...product.modifierGroups.map((group) {
                                int groupSelectedCount = 0;
                                for (var i in group.items) {
                                  if (selectedModifierIds.contains(i.id)) groupSelectedCount++;
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            group.name,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          if (group.isRequired)
                                            Text(
                                              groupSelectedCount < group.minSelect ? '(Zorunlu)' : '(Seçildi)',
                                              style: TextStyle(
                                                color: groupSelectedCount < group.minSelect ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                        ],
                                      ),
                                    ),
                                    ...group.items.map((item) {
                                      final isSelected = selectedModifierIds.contains(item.id);
                                      return CheckboxListTile(
                                        value: isSelected,
                                        title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        subtitle: item.priceCents > 0
                                            ? Text('+ ${(item.priceCents / 100).toStringAsFixed(2)} ₺', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))
                                            : null,
                                        checkColor: Colors.white,
                                        activeColor: const Color(0xFF10B981),
                                        side: const BorderSide(color: Color(0xFF334155)),
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (val == true) {
                                              if (group.maxSelect == 1) {
                                                for (var other in group.items) {
                                                  selectedModifierIds.remove(other.id);
                                                }
                                                selectedModifierIds.add(item.id);
                                              } else {
                                                if (groupSelectedCount < group.maxSelect) {
                                                  selectedModifierIds.add(item.id);
                                                }
                                              }
                                            } else {
                                              selectedModifierIds.remove(item.id);
                                            }
                                          });
                                        },
                                      );
                                    }),
                                    const Divider(color: Color(0xFF334155)),
                                  ],
                                );
                              }),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Özel Not / Açıklama',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextField(
                              controller: noteController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Örn: Az pişmiş, buzsuz, sossuz...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xFF334155)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Birim Fiyat:', style: TextStyle(color: Colors.white70, fontSize: 15)),
                        Text(
                          '${currentPrice.toStringAsFixed(2)} ₺',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid ? const Color(0xFF10B981) : const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isValid
                            ? () {
                                final customNote = noteController.text.trim();
                                ref.read(cartProvider).addProduct(
                                  product,
                                  modifiers: selectedModifiersList,
                                );
                                if (customNote.isNotEmpty) {
                                  final items = ref.read(cartProvider).items;
                                  final lastIdx = items.lastIndexWhere((i) => i.product.id == product.id);
                                  if (lastIdx >= 0) {
                                    ref.read(cartProvider).updateNote(lastIdx, customNote);
                                  }
                                }
                                Navigator.of(ctx).pop();
                              }
                            : null,
                        child: const Text('Sepete Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.existingOrderId != null ? '${widget.table.name} • Ürün Ekle' : '${widget.table.name} • Yeni Sipariş',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: _showCartSheet,
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.totalQuantity}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
        error: (err, _) => Center(
          child: Text('Katalog yüklenemedi:\n$err', style: const TextStyle(color: Colors.white70)),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Menü bulunamadı.', style: TextStyle(color: Colors.white70)));
          }

          final activeCategoryId = _selectedCategoryId ?? categories.first.id;
          final activeCategory = categories.firstWhere(
            (c) => c.id == activeCategoryId,
            orElse: () => categories.first,
          );

          return Column(
            children: [
              Container(
                height: 50,
                color: const Color(0xFF1E293B),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat.id == activeCategoryId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        selectedColor: const Color(0xFF38BDF8),
                        backgroundColor: const Color(0xFF334155),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategoryId = cat.id);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: activeCategory.products.isEmpty
                    ? const Center(
                        child: Text('Bu kategoride ürün yok.', style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: activeCategory.products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final product = activeCategory.products[index];
                          final hasModifiers = product.modifierGroups.isNotEmpty;

                          return Stack(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (hasModifiers) {
                                    _showModifierModal(context, product, ref);
                                  } else {
                                    ref.read(cartProvider).addProduct(product);
                                  }
                                },
                                onLongPress: () {
                                  _showModifierModal(context, product, ref);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: hasModifiers ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : const Color(0xFF334155),
                                      width: hasModifiers ? 1.5 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (hasModifiers)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                '✨ Ekstra Seçenekli',
                                                style: TextStyle(
                                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${product.price.toStringAsFixed(2)} ₺',
                                            style: const TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: hasModifiers ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              hasModifiers ? Icons.tune : Icons.add,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.edit_note, color: Colors.white70, size: 24),
                                  tooltip: 'Ekstra Not Ekle',
                                  onPressed: () => _showModifierModal(context, product, ref),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: cart.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: SafeArea(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showCartSheet,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'Sepet (${cart.totalQuantity} Ürün)',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${cart.totalPrice.toStringAsFixed(2)} ₺  >',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}