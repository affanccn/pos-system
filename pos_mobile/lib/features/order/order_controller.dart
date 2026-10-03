import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/catalog_model.dart';
import '../auth/auth_controller.dart';

// Kategorileri ve menü ürünlerini getiren provider
final catalogProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    // Doğru endpoint: /catalog
    final response = await apiClient.dio.get('/catalog');
    final rawData = response.data;

    debugPrint('--> Katalog Yanıtı Geldi: $rawData');

    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      list = (rawData['data'] ?? rawData['categories'] ?? []) as List<dynamic>;
    }

    return list.map((item) => Category.fromJson(item as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('--> Katalog Yükleme Hatası: $e');
    throw Exception('Menü yüklenemedi: $e');
  }
});

// Masaya ait anlık sepet kalemi
class CartItem {
  final Product product;
  int quantity;
  String? note;
  final List<ProductModifierItem> modifiers;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.note,
    this.modifiers = const [],
  });

  double get unitPrice {
    double p = product.price;
    for (var m in modifiers) {
      p += m.priceCents / 100.0;
    }
    return p;
  }

  double get total => unitPrice * quantity;

  // Aynı ürünün aynı modifier'larla sepete eklenip eklenmediğini kontrol etmek için
  bool isSameAs(Product p, List<ProductModifierItem> mods) {
    if (p.id != product.id) return false;
    if (mods.length != modifiers.length) return false;
    
    final myModIds = modifiers.map((m) => m.id).toList()..sort();
    final otherModIds = mods.map((m) => m.id).toList()..sort();
    
    for (int i = 0; i < myModIds.length; i++) {
      if (myModIds[i] != otherModIds[i]) return false;
    }
    return true;
  }
}

// Sepet Durum Yönetimi
class CartNotifier extends ChangeNotifier {
  List<CartItem> _items = [];

  List<CartItem> get items => _items;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  void addProduct(Product product, {List<ProductModifierItem>? modifiers}) {
    final mods = modifiers ?? [];
    final index = _items.indexWhere((item) => item.isSameAs(product, mods));
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, quantity: 1, modifiers: mods));
    }
    notifyListeners();
  }

  void removeProductAt(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void addProductAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void updateNote(int index, String? note) {
    if (index >= 0 && index < _items.length) {
      _items[index].note = note;
      notifyListeners();
    }
  }

  void clearCart() {
    _items = [];
    notifyListeners();
  }

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.total);
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = ChangeNotifierProvider.autoDispose<CartNotifier>((ref) {
  return CartNotifier();
});