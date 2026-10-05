import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/catalog_model.dart';
import '../auth/auth_controller.dart';
import '../order/order_controller.dart';
import 'product_form_screen.dart';
import '../../core/widgets/app_states.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    showAppDialog(
      context: context,
      title: 'Yeni Kategori Ekle',
      content: TextField(
        controller: nameCtrl,
        decoration: InputDecoration(labelText: 'Kategori Adı'),
        autofocus: true,
      ),
      confirmText: 'Ekle',
      onConfirm: () async {
        if (nameCtrl.text.isEmpty) return;
        try {
          final apiClient = ref.read(apiClientProvider);
          await apiClient.dio.post('/catalog/categories', data: {'name': nameCtrl.text});
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  void _showAddModifierItemDialog(ProductModifierGroup group) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showAppDialog(
      context: context,
      title: '${group.name} - Yeni Seçenek',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Seçenek Adı (Örn: Karamel Şurubu)',
              labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
            ),
            autofocus: true,
          ),
          SizedBox(height: 12),
          TextField(
            controller: priceCtrl,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Fiyat (TL)',
              labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
            ),
          ),
        ],
      ),
      confirmText: 'Ekle',
      onConfirm: () async {
        if (nameCtrl.text.isEmpty) return;
        final price = double.tryParse(priceCtrl.text) ?? 0.0;
        final apiClient = ref.read(apiClientProvider);
        try {
          await apiClient.dio.post(
            '/catalog/modifier-items',
            data: {
              'modifierGroupId': group.id,
              'name': nameCtrl.text,
              'priceCents': (price * 100).toInt(),
            },
          );
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  void _deleteModifierItem(String id) {
    showAppDialog(
      context: context,
      title: 'Silme Onayı',
      content: Text('Bu seçeneği silmek istediğinize emin misiniz?', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
      confirmText: 'Sil',
      isDestructive: true,
      onConfirm: () async {
        final apiClient = ref.read(apiClientProvider);
        try {
          await apiClient.dio.delete('/catalog/modifier-items/$id');
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  void _showAddModifierGroupDialog(Product product) {
    final nameCtrl = TextEditingController();
    bool isRequired = false;
    showAppDialog(
      context: context,
      title: '${product.name} - Yeni Grup',
      content: StatefulBuilder(
        builder: (_, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Grup Adı (Örn: Şuruplar)',
                  labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                ),
                autofocus: true,
              ),
              SizedBox(height: 12),
              SwitchListTile(
                title: Text(
                  'Zorunlu Seçim',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                value: isRequired,
                onChanged: (v) => setState(() => isRequired = v),
                activeThumbColor: const Color(0xFF38BDF8),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          );
        },
      ),
      confirmText: 'Ekle',
      onConfirm: () async {
        if (nameCtrl.text.isEmpty) return;
        final apiClient = ref.read(apiClientProvider);
        try {
          await apiClient.dio.post(
            '/catalog/modifier-groups',
            data: {
              'productId': product.id,
              'name': nameCtrl.text,
              'isRequired': isRequired,
              'minSelect': isRequired ? 1 : 0,
              'maxSelect': 5,
            },
          );
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  void _deleteModifierGroup(String id) {
    showAppDialog(
      context: context,
      title: 'Silme Onayı',
      content: Text('Bu grubu silmek istediğinize emin misiniz? Grubun içindeki seçenekler de silinebilir.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
      confirmText: 'Sil',
      isDestructive: true,
      onConfirm: () async {
        final apiClient = ref.read(apiClientProvider);
        try {
          await apiClient.dio.delete('/catalog/modifier-groups/$id');
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  void _deleteProduct(String id) {
    showAppDialog(
      context: context,
      title: 'Silme Onayı',
      content: Text('Bu ürünü silmek istediğinize emin misiniz?', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
      confirmText: 'Sil',
      isDestructive: true,
      onConfirm: () async {
        final apiClient = ref.read(apiClientProvider);
        try {
          await apiClient.dio.delete('/catalog/products/$id');
          if (mounted) Navigator.pop(context);
          ref.invalidate(catalogProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Menü & Ekstralar',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        icon: Icon(Icons.add),
        label: Text('Kategori Ekle'),
      ),
      body: catalogAsync.when(
        loading: () => const AppLoadingState(message: 'Katalog yükleniyor...'),
        error: (err, _) => AppErrorState(
          message: 'Katalog yüklenemedi: $err',
          onRetry: () => ref.invalidate(catalogProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return AppEmptyState(
              message: 'Henüz kategori bulunmuyor.',
              icon: Icons.category,
              actionLabel: 'Kategori Ekle',
              onAction: () => _showAddCategoryDialog(),
            );
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.green),
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductFormScreen(categoryId: category.id),
                          ),
                        );
                        if (res == true) ref.invalidate(catalogProvider);
                      },
                    ),
                  ],
                ),
                children: category.products.map((product) {
                  return Card(
                    color: Theme.of(context).dividerColor,
                    margin: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ExpansionTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductFormScreen(
                                        product: product,
                                        categoryId: category.id,
                                      ),
                                    ),
                                  );
                                  if (res == true) {
                                    ref.invalidate(catalogProvider);
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteProduct(product.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${(product.priceCents / 100).toStringAsFixed(2)} TL',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                      children: [
                        ...product.modifierGroups.map((group) {
                          return Container(
                            margin: EdgeInsets.all(8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${group.name} ${group.isRequired ? "(Zorunlu)" : ""}',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.add_circle,
                                            color: Colors.blueAccent,
                                          ),
                                          onPressed: () =>
                                              _showAddModifierItemDialog(group),
                                          tooltip: 'Seçenek Ekle',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () =>
                                              _deleteModifierGroup(group.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                ...group.items.map((item) {
                                  return ListTile(
                                    title: Text(
                                      item.name,
                                      style: TextStyle(
                                        color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '+${(item.priceCents / 100).toStringAsFixed(2)} TL',
                                          style: TextStyle(
                                            color: Colors.green,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteModifierItem(item.id),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () => _showAddModifierGroupDialog(product),
                          icon: Icon(Icons.add),
                          label: Text('Yeni Ekstra Grubu Ekle'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
