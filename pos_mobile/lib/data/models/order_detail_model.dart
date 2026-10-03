class ActiveOrderItemModifier {
  final String id;
  final String name;
  final int priceCents;
  final int quantity;

  ActiveOrderItemModifier({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  factory ActiveOrderItemModifier.fromJson(Map<String, dynamic> json) {
    return ActiveOrderItemModifier(
      id: json['id']?.toString() ?? '',
      name: json['modifierNameSnapshot']?.toString() ?? '',
      priceCents: json['priceCentsSnapshot'] is int ? json['priceCentsSnapshot'] : int.tryParse(json['priceCentsSnapshot']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
    );
  }
}

class ActiveOrderItem {
  final String id;
  final String productName;
  final int quantity;
  final int unitPriceCents;
  final int totalPriceCents;
  final String? notes;
  final List<ActiveOrderItemModifier> modifiers;

  ActiveOrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPriceCents,
    required this.totalPriceCents,
    this.notes,
    this.modifiers = const [],
  });

  double get unitPrice => unitPriceCents / 100.0;
  double get totalPrice => totalPriceCents / 100.0;

  factory ActiveOrderItem.fromJson(Map<String, dynamic> json) {
    final rawModifiers = json['modifiers'] as List<dynamic>? ?? [];
    return ActiveOrderItem(
      id: json['id']?.toString() ?? '',
      productName: json['productNameSnapshot']?.toString() ?? 'Ürün',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity'].toString()) ?? 1,
      unitPriceCents: json['unitPriceCents'] is int ? json['unitPriceCents'] : int.tryParse(json['unitPriceCents'].toString()) ?? 0,
      totalPriceCents: json['totalPriceCents'] is int ? json['totalPriceCents'] : int.tryParse(json['totalPriceCents'].toString()) ?? 0,
      notes: json['notes']?.toString(),
      modifiers: rawModifiers.map((m) => ActiveOrderItemModifier.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

class ActiveOrder {
  final String id;
  final int orderNumber;
  final String status;
  final int totalAmountCents;
  final String? waiterName;
  final List<ActiveOrderItem> items;

  ActiveOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmountCents,
    this.waiterName,
    required this.items,
  });

  double get totalAmount => totalAmountCents / 100.0;

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ActiveOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber'] is int ? json['orderNumber'] : int.tryParse(json['orderNumber'].toString()) ?? 0,
      status: json['status']?.toString() ?? 'CONFIRMED',
      totalAmountCents: json['totalAmountCents'] is int ? json['totalAmountCents'] : int.tryParse(json['totalAmountCents'].toString()) ?? 0,
      waiterName: json['waiter']?['fullName']?.toString(),
      items: rawItems.map((i) => ActiveOrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}