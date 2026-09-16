import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_item.dart';

void main() {
  group('MaintenanceItem.fromJson', () {
    test('prefers nested warranty snapshot over legacy columns', () {
      final item = MaintenanceItem.fromJson({
        'id': 1,
        'name': 'Pastilha',
        'quantity': 2,
        'unit_price': '50.00',
        'total_price': '100.00',
        'has_warranty': false,
        'warranty_starts_at': null,
        'warranty_ends_at': null,
        'warranty_period_label': 'Garantia até 01/08/2026',
        'is_under_warranty': true,
        'warranty': {
          'id': 7,
          'scope': 'item',
          'name': 'Garantia peça',
          'duration_days': 180,
          'starts_at': '2026-02-01',
          'ends_at': '2026-08-01',
          'label': 'Em garantia até 01/08/2026',
          'is_vigente': true,
          'warranty_template_id': 4,
        },
      });

      expect(item.hasWarranty, isTrue);
      expect(item.warrantyName, 'Garantia peça');
      expect(item.isUnderWarranty, isTrue);
      expect(item.warrantyTemplateId, 4);
      expect(item.displayWarrantyLabel, 'Em garantia até 01/08/2026');
    });

    test('toJson sends warranty_template_id without legacy dates', () {
      final item = MaintenanceItem(
        name: 'Filtro',
        quantity: 1,
        unitPrice: 20,
        totalPrice: 20,
        warrantyTemplateId: 9,
      );

      final json = item.toJson();

      expect(json['warranty_template_id'], 9);
      expect(json.containsKey('has_warranty'), isFalse);
      expect(json.containsKey('warranty_starts_at'), isFalse);
      expect(json.containsKey('warranty_ends_at'), isFalse);
    });
  });
}
