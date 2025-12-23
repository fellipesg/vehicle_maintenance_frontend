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
    // Helper function to safely convert to double
    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return MaintenanceItem(
      id: json['id'],
      maintenanceId: json['maintenance_id'],
      name: json['name'] ?? '',
      description: json['description'],
      quantity: json['quantity'] ?? 1,
      unitPrice: _parseDouble(json['unit_price']),
      totalPrice: _parseDouble(json['total_price']),
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
