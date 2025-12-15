class Invoice {
  final int? id;
  final int maintenanceId;
  final int? maintenanceItemId;
  final String invoiceType;
  final String filePath;
  final String fileName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final double? totalAmount;

  Invoice({
    this.id,
    required this.maintenanceId,
    this.maintenanceItemId,
    required this.invoiceType,
    required this.filePath,
    required this.fileName,
    this.invoiceNumber,
    this.invoiceDate,
    this.totalAmount,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      maintenanceId: json['maintenance_id'] ?? 0,
      maintenanceItemId: json['maintenance_item_id'],
      invoiceType: json['invoice_type'] ?? 'general',
      filePath: json['file_path'] ?? '',
      fileName: json['file_name'] ?? '',
      invoiceNumber: json['invoice_number'],
      invoiceDate: json['invoice_date'] != null
          ? DateTime.parse(json['invoice_date'])
          : null,
      totalAmount: json['total_amount'] != null
          ? double.tryParse(json['total_amount'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'maintenance_id': maintenanceId,
      'maintenance_item_id': maintenanceItemId,
      'invoice_type': invoiceType,
      'file_path': filePath,
      'file_name': fileName,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate?.toIso8601String().split('T')[0],
      'total_amount': totalAmount,
    };
  }

  // Get the full URL for the invoice file using the download endpoint
  String getFileUrl(String baseUrl) {
    // Use the download endpoint from the API
    return '$baseUrl/invoices/$id/download';
  }
}
