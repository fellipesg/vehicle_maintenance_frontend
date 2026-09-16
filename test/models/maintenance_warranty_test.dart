import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance_warranty.dart';

void main() {
  group('MaintenanceWarranty.fromJson', () {
    test('parses general warranty snapshot from API resource', () {
      final warranty = MaintenanceWarranty.fromJson({
        'id': 10,
        'maintenance_id': 5,
        'maintenance_item_id': null,
        'warranty_template_id': 3,
        'scope': 'order',
        'name': 'Garantia OS',
        'body': 'Termo completo',
        'duration_days': 90,
        'starts_at': '2026-02-01',
        'ends_at': '2026-05-02',
        'label': 'Em garantia até 02/05/2026',
        'is_vigente': true,
      });

      expect(warranty.id, 10);
      expect(warranty.scope, 'order');
      expect(warranty.name, 'Garantia OS');
      expect(warranty.durationDays, 90);
      expect(warranty.startsAt, DateTime.parse('2026-02-01'));
      expect(warranty.endsAt, DateTime.parse('2026-05-02'));
      expect(warranty.label, 'Em garantia até 02/05/2026');
      expect(warranty.isVigente, isTrue);
    });
  });
}
