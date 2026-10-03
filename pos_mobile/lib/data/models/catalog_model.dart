class ProductModifierItem {
  final String id;
  final String name;
  final int priceCents;

  ProductModifierItem({
    required this.id,
    required this.name,
    required this.priceCents,
  });

  factory ProductModifierItem.fromJson(Map<String, dynamic> json) {
    return ProductModifierItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceCents: json['priceCents'] is int ? json['priceCents'] : int.tryParse(json['priceCents']?.toString() ?? '0') ?? 0,
    );
  }
}

class ProductModifierGroup {
  final String id;
  final String name;
  final bool isRequired;
  final int minSelect;
  final int maxSelect;
  final List<ProductModifierItem> items;

  ProductModifierGroup({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.minSelect,
    required this.maxSelect,
    required this.items,
  });

  factory ProductModifierGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ProductModifierGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isRequired: json['isRequired'] as bool? ?? false,
      minSelect: json['minSelect'] as int? ?? 0,
      maxSelect: json['maxSelect'] as int? ?? 1,
      items: rawItems.map((i) => ProductModifierItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}

class StockItem {
  final String id;
  final String name;
  final String unit;
  final double currentAmount;
  final int unitCostCents;

  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentAmount,
    required this.unitCostCents,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
      unitCostCents: json['unitCostCents'] as int? ?? 0,
    );
  }
}

class ProductRecipeItem {
  final String id;
  final String stockItemId;
  final double quantity;
  final int wastePercentage;
  final int costCents;
  final StockItem? stockItem;

  ProductRecipeItem({
    required this.id,
    required this.stockItemId,
    required this.quantity,
    required this.wastePercentage,
    required this.costCents,
    this.stockItem,
  });

  factory ProductRecipeItem.fromJson(Map<String, dynamic> json) {
    return ProductRecipeItem(
      id: json['id']?.toString() ?? '',
      stockItemId: json['stockItemId']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      wastePercentage: json['wastePercentage'] as int? ?? 0,
      costCents: json['costCents'] as int? ?? 0,
      stockItem: json['stockItem'] != null ? StockItem.fromJson(json['stockItem']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'stockItemId': stockItemId,
      'quantity': quantity,
      'wastePercentage': wastePercentage,
      'costCents': costCents,
    };
  }
}

class Product {
  final String id;
  final String name;
  final int priceCents;
  final String? categoryId;
  final String? description;
  final int taxRate;
  final int costCents;
  final String? stationType;
  final String? imageUrl;
  final List<ProductModifierGroup> modifierGroups;
  final List<ProductRecipeItem> recipeItems;

  Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.categoryId,
    this.description,
    this.taxRate = 0,
    this.costCents = 0,
    this.stationType,
    this.imageUrl,
    this.modifierGroups = const [],
    this.recipeItems = const [],
  });

  double get price => priceCents / 100.0;
  double get cost => costCents / 100.0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['modifierGroups'] as List<dynamic>? ?? [];
    final rawRecipes = json['recipeItems'] as List<dynamic>? ?? [];
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceCents: json['priceCents'] is int
          ? json['priceCents']
          : int.tryParse(json['priceCents']?.toString() ?? '0') ?? 0,
      categoryId: json['categoryId']?.toString(),
      description: json['description']?.toString(),
      taxRate: json['taxRate'] as int? ?? 0,
      costCents: json['costCents'] as int? ?? 0,
      stationType: json['stationType']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      modifierGroups: rawGroups.map((g) => ProductModifierGroup.fromJson(g as Map<String, dynamic>)).toList(),
      recipeItems: rawRecipes.map((r) => ProductRecipeItem.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

class Category {
  final String id;
  final String name;
  final List<Product> products;

  Category({
    required this.id,
    required this.name,
    required this.products,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'] as List<dynamic>? ?? [];
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      products: rawProducts
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}