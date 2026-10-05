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
              backgroundColor: Theme.of(context).cardColor,
              title: Text('Reçete Malzemesi Ekle', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<StockItem>(
                    value: selected,
                    dropdownColor: Theme.of(context).dividerColor,
                    isExpanded: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    items: _availableStocks.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.unit})'))).toList(),
                    onChanged: (val) => setStateDialog(() => selected = val),
                  ),
                  TextField(controller: qtyCtrl, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), decoration: InputDecoration(labelText: 'Miktar', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))), keyboardType: TextInputType.number),
                  TextField(controller: wasteCtrl, style: TextStyle(color: Theme.of(context).colorScheme.onSurface), decoration: InputDecoration(labelText: 'Fire (%)', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))), keyboardType: TextInputType.number),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal')),
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
                  child: Text('Ekle'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.product == null ? 'Yeni Ürün' : 'Ürün Düzenle', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(
            icon: _isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface, strokeWidth: 2)) : Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoadingStocks ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(labelText: 'Ürün Adı', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                        validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                      TextFormField(
                        controller: _descCtrl,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                      ),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _priceCtrl,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(labelText: 'Fiyat (TL)', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                          )),
                          SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _taxCtrl,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(labelText: 'KDV (%)', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                            keyboardType: TextInputType.number,
                          )),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _costCtrl,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(labelText: 'Maliyet (TL)', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                            keyboardType: TextInputType.number,
                          )),
                          SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _stationType,
                              dropdownColor: Theme.of(context).dividerColor,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(labelText: 'İstasyon', labelStyle: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
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
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reçete (İçindekiler)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _addRecipeItem,
                    icon: Icon(Icons.add),
                    label: Text('Malzeme Ekle'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
                  )
                ],
              ),
              SizedBox(height: 8),
              if (_recipeItems.isEmpty)
                Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Reçete eklenmemiş.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))))),
              ..._recipeItems.map((r) => Card(
                color: Theme.of(context).dividerColor,
                child: ListTile(
                  title: Text(r.stockItem?.name ?? 'Bilinmeyen', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text('Miktar: ${r.quantity} ${r.stockItem?.unit ?? ''} | Fire: %${r.wastePercentage} | Maliyet: ${(r.costCents / 100).toStringAsFixed(2)} TL', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.redAccent),
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
