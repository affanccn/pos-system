import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/catalog_model.dart';
import '../auth/auth_controller.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? categoryId;

  const ProductFormScreen({super.key, this.product, this.categoryId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _imgCtrl;
  
  String? _stationType;
  final List<String> _stationTypes = ['KITCHEN', 'BAR', 'DESSERT', 'COFFEE'];
  
  List<ProductRecipeItem> _recipeItems = [];
  List<StockItem> _availableStocks = [];
  bool _isLoadingStocks = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _priceCtrl = TextEditingController(text: widget.product != null ? widget.product!.price.toStringAsFixed(2) : '');
    _taxCtrl = TextEditingController(text: widget.product?.taxRate.toString() ?? '0');
    _costCtrl = TextEditingController(text: widget.product != null ? widget.product!.cost.toStringAsFixed(2) : '');
    _imgCtrl = TextEditingController(text: widget.product?.imageUrl ?? '');
    _stationType = widget.product?.stationType;
    if (_stationType != null && !_stationTypes.contains(_stationType)) {
       _stationType = null;
    }
    
    if (widget.product != null) {
      _recipeItems = List.from(widget.product!.recipeItems);
    }
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/stock');
      final data = res.data['data'] as List;
      setState(() {
        _availableStocks = data.map((e) => StockItem.fromJson(e)).toList();
        _isLoadingStocks = false;
      });
    } catch (e) {
      setState(() => _isLoadingStocks = false);
    }
  }

  void _addRecipeItem() {
    if (_availableStocks.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        StockItem? selected = _availableStocks.first;
        final qtyCtrl = TextEditingController(text: '1');
        final wasteCtrl = TextEditingController(text: '0');
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Reçete Malzemesi Ekle', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<StockItem>(
                    value: selected,
                    dropdownColor: const Color(0xFF334155),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: _availableStocks.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.unit})'))).toList(),
                    onChanged: (val) => setStateDialog(() => selected = val),
                  ),
                  TextField(controller: qtyCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Miktar', labelStyle: TextStyle(color: Colors.white70)), keyboardType: TextInputType.number),
                  TextField(controller: wasteCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Fire (%)', labelStyle: TextStyle(color: Colors.white70)), keyboardType: TextInputType.number),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: () {
                    if (selected == null) return;
                    final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                    final waste = int.tryParse(wasteCtrl.text) ?? 0;
                    final costCents = ((selected!.unitCostCents * qty) * (1 + (waste / 100))).round();
                    
                    setState(() {
                      _recipeItems.add(ProductRecipeItem(
                        id: '',
                        stockItemId: selected!.id,
                        quantity: qty,
                        wastePercentage: waste,
                        costCents: costCents,
                        stockItem: selected,
                      ));
                      double totalCost = 0;
                      for (var item in _recipeItems) {
                        totalCost += item.costCents / 100;
                      }
                      _costCtrl.text = totalCost.toStringAsFixed(2);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);
    
    final data = {
      'name': _nameCtrl.text,
      'description': _descCtrl.text,
      'priceCents': ((double.tryParse(_priceCtrl.text) ?? 0) * 100).toInt(),
      'taxRate': int.tryParse(_taxCtrl.text) ?? 0,
      'costCents': ((double.tryParse(_costCtrl.text) ?? 0) * 100).toInt(),
      'imageUrl': _imgCtrl.text,
      'stationType': _stationType,
      'categoryId': widget.categoryId,
      'recipeItems': _recipeItems.map((r) => r.toJson()).toList(),
    };

    try {
      if (widget.product == null) {
        await apiClient.dio.post('/catalog/products', data: data);
      } else {
        await apiClient.dio.put('/catalog/products/${widget.product!.id}', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.product == null ? 'Yeni Ürün' : 'Ürün Düzenle', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoadingStocks ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: const Color(0xFF1E293B),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Ürün Adı', labelStyle: TextStyle(color: Colors.white70)),
                        validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                      TextFormField(
                        controller: _descCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _priceCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Fiyat (TL)', labelStyle: TextStyle(color: Colors.white70)),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _taxCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'KDV (%)', labelStyle: TextStyle(color: Colors.white70)),
                            keyboardType: TextInputType.number,
                          )),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _costCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Maliyet (TL)', labelStyle: TextStyle(color: Colors.white70)),
                            keyboardType: TextInputType.number,
                          )),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _stationType,
                              dropdownColor: const Color(0xFF334155),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'İstasyon', labelStyle: TextStyle(color: Colors.white70)),
                              items: _stationTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setState(() => _stationType = val),
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reçete (İçindekiler)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _addRecipeItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Malzeme Ekle'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (_recipeItems.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Reçete eklenmemiş.', style: TextStyle(color: Colors.white54)))),
              ..._recipeItems.map((r) => Card(
                color: const Color(0xFF334155),
                child: ListTile(
                  title: Text(r.stockItem?.name ?? 'Bilinmeyen', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Miktar: ${r.quantity} ${r.stockItem?.unit ?? ''} | Fire: %${r.wastePercentage} | Maliyet: ${(r.costCents / 100).toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.white70)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _recipeItems.remove(r);
                      });
                    },
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
