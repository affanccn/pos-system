class Printer {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String? stationType; // KITCHEN, BAR vs. Kasa için null olabilir
  final bool isCashier;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Printer({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.port = 9100,
    this.stationType,
    this.isCashier = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int? ?? 9100,
      stationType: json['stationType'] as String?,
      isCashier: json['isCashier'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'stationType': stationType,
      'isCashier': isCashier,
      'isActive': isActive,
    };
  }
}
