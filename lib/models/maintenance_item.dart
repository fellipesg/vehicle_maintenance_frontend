class MaintenanceItem {
  final int? id;
  final int? maintenanceId;
  final String name;
  final String? description;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? partNumber;

  MaintenanceItem({
    this.id,
    this.maintenanceId,
    required this.name,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.partNumber,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      id: json['id'],
      maintenanceId: json['maintenance_id'],
      name: json['name'] ?? '',
      description: json['description'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      totalPrice: (json['total_price'] ?? 0.0).toDouble(),
      partNumber: json['part_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (maintenanceId != null) 'maintenance_id': maintenanceId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice.toStringAsFixed(2),
      'total_price': totalPrice.toStringAsFixed(2),
      'part_number': partNumber,
    };
  }
}

