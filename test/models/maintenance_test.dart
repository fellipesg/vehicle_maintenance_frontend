import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance.dart';

void main() {
  test('Maintenance.fromJson parses general_warranty and workshop logo', () {
    final maintenance = Maintenance.fromJson({
      'id': 1,
      'vehicle_id': 10,
      'maintenance_type': 'Revisão',
      'maintenance_date': '2026-02-01',
      'general_warranty': {
        'id': 3,
        'scope': 'order',
        'name': 'Garantia geral',
        'duration_days': 90,
        'starts_at': '2026-02-01',
        'ends_at': '2026-05-02',
        'label': 'Em garantia até 02/05/2026',
        'is_vigente': true,
      },
      'workshop': {
        'id': 2,
        'name': 'Oficina Teste',
        'phone': '11999999999',
        'cep': '01310100',
        'street': 'Av Paulista',
        'number': '1000',
        'neighborhood': 'Bela Vista',
        'city': 'São Paulo',
        'state': 'SP',
        'logo_url': 'https://cdn.example/workshop-logos/2.jpg',
      },
    });

    expect(maintenance.generalWarranty?.name, 'Garantia geral');
    expect(maintenance.generalWarranty?.isVigente, isTrue);
    expect(maintenance.workshop?.logoUrl,
        'https://cdn.example/workshop-logos/2.jpg');
  });

  test('Maintenance.fromJson parses provenance and hasInvoices', () {
    final maintenance = Maintenance.fromJson({
      'id': 2,
      'vehicle_id': 1,
      'maintenance_type': 'Revisão',
      'maintenance_date': '2026-01-15',
      'is_verified': true,
      'registered_by_type': 'workshop',
      'provenance_label': 'Selo da oficina',
      'verification_code': 'ABCD1234',
      'verification_url': 'https://revisalog.com.br/v/ABCD1234',
      'invoices': [
        {
          'id': 1,
          'maintenance_id': 2,
          'invoice_type': 'general',
          'file_name': 'nf.pdf',
        },
      ],
    });

    expect(maintenance.isVerified, isTrue);
    expect(maintenance.hasInvoices, isTrue);
    expect(maintenance.verificationCode, 'ABCD1234');
  });
}
