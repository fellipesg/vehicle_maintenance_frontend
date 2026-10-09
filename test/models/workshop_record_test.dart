import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/models/maintenance.dart';
import 'package:vehicle_maintenance/models/vehicle.dart';
import 'package:vehicle_maintenance/models/workshop_record.dart';
import 'package:vehicle_maintenance/models/workshop_vehicle_lookup.dart';

import '../support_workshop_records.dart';

void main() {
  test('WorkshopRecord parses the full contract', () {
    final record = WorkshopRecord.fromJson(recordJson());

    expect(record.id, 1);
    expect(record.vehicle.displayName, 'Fiat Uno');
    expect(record.vehicle.chassisMasked, '9BD*********1234');
    expect(record.workshop.name, 'Oficina Central');
    expect(record.maintenanceDate, DateTime(2026, 9, 1));
    expect(record.attachmentsCount, 3);
    expect(record.items.single.name, 'Óleo');
    expect(record.ownerStatus, OwnerStatus.pending);
    expect(record.attachmentsStatus, AttachmentsStatus.pending);
    expect(record.canAcceptAttachments, isTrue);
  });

  test('WorkshopRecord tolerates missing fields', () {
    final record = WorkshopRecord.fromJson({'id': 5});

    expect(record.vehicle.displayName, 'Veículo');
    expect(record.attachmentsCount, 0);
    expect(record.ownerStatus, OwnerStatus.pending);
    expect(record.attachmentsStatus, AttachmentsStatus.none);
    expect(record.canAcceptAttachments, isFalse);
    expect(record.hiddenFromPublic, isFalse);
    expect(WorkshopRecord.listFromEnvelope(null), isEmpty);
  });

  test('Maintenance parses ownerless fields and stays compatible without them',
      () {
    final ownerless = Maintenance.fromJson({
      'id': 1,
      'maintenance_type': 'x',
      'is_ownerless_record': true,
      'owner_status': 'pending',
      'attachments_status': 'pending',
      'hidden_from_public': true,
    });
    final legacy = Maintenance.fromJson({'id': 2, 'maintenance_type': 'x'});

    expect(ownerless.isAwaitingOwner, isTrue);
    expect(ownerless.hiddenFromPublic, isTrue);
    expect(legacy.isOwnerlessRecord, isFalse);
    expect(legacy.isAwaitingOwner, isFalse);
    expect(legacy.ownerStatus, isNull);
  });

  test('Vehicle without plate shows "Placa não informada"', () {
    final vehicle = Vehicle.fromJson({
      'id': 1,
      'license_plate': null,
      'brand': 'Fiat',
      'model': 'Uno',
      'year': 2012,
    });

    expect(vehicle.licensePlate, isNull);
    expect(vehicle.hasPlate, isFalse);
    expect(vehicle.plateLabel, 'Placa não informada');
    expect(vehicle.fullInfo, isNot(contains('null')));
  });

  test('WorkshopVehicleLookup handles found, owned and not found', () {
    final notFound = WorkshopVehicleLookup.fromEnvelope(
      {
        'data': {'found': false, 'vehicle': null}
      },
    );
    final owned = WorkshopVehicleLookup.fromEnvelope({
      'data': {
        'found': true,
        'vehicle': {'id': 4, 'has_owner': true},
      },
    });
    final free = WorkshopVehicleLookup.fromEnvelope({
      'data': {
        'found': true,
        'vehicle': {'id': 5, 'brand': 'Fiat', 'model': 'Uno', 'year': 2012},
      },
    });

    expect(notFound.found, isFalse);
    expect(owned.hasOwner, isTrue);
    expect(owned.isOwnerless, isFalse);
    expect(free.isOwnerless, isTrue);
    expect(free.displayName, 'Fiat Uno');
  });
}
