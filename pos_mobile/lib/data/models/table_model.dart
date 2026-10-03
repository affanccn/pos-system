class RestaurantTable {
  final String id;
  final String name;
  final String status;
  final int capacity;
  final String? currentOrderId;
  final int sortOrder;
  final String section;

  RestaurantTable({
    required this.id,
    required this.name,
    required this.status,
    required this.capacity,
    this.currentOrderId,
    this.sortOrder = 0,
    this.section = 'Salon',
  });

  String get displayName {
    return name;
  }

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      capacity: json['capacity'] as int? ?? 4,
      currentOrderId: json['currentOrderId'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      section: json['section'] as String? ?? 'Salon',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'capacity': capacity,
      'currentOrderId': currentOrderId,
      'sortOrder': sortOrder,
      'section': section,
    };
  }
}