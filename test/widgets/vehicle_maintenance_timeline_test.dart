import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_maintenance/models/provenance_segment.dart';
import 'package:vehicle_maintenance/services/api_service.dart';
import 'package:vehicle_maintenance/services/auth_service.dart';
import 'package:vehicle_maintenance/views/maintenances/maintenance_detail_page.dart';
import 'package:vehicle_maintenance/widgets/vehicle_maintenance_timeline.dart';

class _TimelineNavFakeApi extends ApiService {
  _TimelineNavFakeApi() : super(baseUrl: 'http://test');

  @override
  Future<Response<dynamic>> getMaintenance(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/maintenances/$id'),
      data: {
        'success': true,
        'data': {
          'id': int.parse(id),
          'vehicle_id': 1,
          'maintenance_type': 'Revisão',
          'maintenance_date': '2024-06-01',
        },
      },
    );
  }

  @override
  Future<Response<dynamic>> getVehicle(String id) async {
    return Response(
      requestOptions: RequestOptions(path: '/vehicles/$id'),
      data: {
        'success': true,
        'data': {'id': 1, 'brand': 'VW', 'model': 'Gol'},
      },
    );
  }
}

void main() {
  testWidgets('lays out inside vertical scroll without layout exceptions',
      (tester) async {
    final timeline = {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 2,
        'total_spent': 500,
      },
      'vehicle': {'brand': 'Mercedes-Benz', 'model': 'C 180'},
      'events': [
        {
          'type': 'registration',
          'label': 'Cadastro',
          'date': '2018-01-01',
          'kilometers': 0,
        },
        {
          'type': 'maintenance',
          'id': 1,
          'label': 'Revisão',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': true,
          'workshop_name': 'Oficina Demo',
        },
        {
          'type': 'maintenance',
          'id': 2,
          'label': 'Troca de óleo',
          'date': '2025-01-01',
          'kilometers': 110000,
          'is_verified': false,
          'is_current': true,
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleMaintenanceTimeline(timeline: timeline),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Linha do tempo'), findsOneWidget);
    expect(find.textContaining('Revisão'), findsOneWidget);
    expect(find.textContaining('Troca de óleo'), findsWidgets);
  });

  testWidgets('verified filter shows only verified maintenance events',
      (tester) async {
    final timeline = {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 2,
        'total_spent': 500,
      },
      'vehicle': {'brand': 'Mercedes-Benz', 'model': 'C 180'},
      'events': [
        {
          'type': 'maintenance',
          'id': 1,
          'label': 'Revisão verificada',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': true,
        },
        {
          'type': 'maintenance',
          'id': 2,
          'label': 'Troca declarada',
          'date': '2025-01-01',
          'kilometers': 110000,
          'is_verified': false,
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleMaintenanceTimeline(
            timeline: timeline,
            verifiedFilter: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Revisão verificada'), findsWidgets);
    expect(find.textContaining('Troca declarada'), findsNothing);
  });

  testWidgets('tapping maintenance event opens maintenance detail',
      (tester) async {
    final timeline = {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 1,
        'total_spent': 500,
      },
      'vehicle': {'brand': 'VW', 'model': 'Gol'},
      'events': [
        {
          'type': 'maintenance',
          'id': 42,
          'label': 'Revisão',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': true,
        },
      ],
    };

    final api = _TimelineNavFakeApi();
    final auth = AuthService(api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          Provider<AuthService>.value(value: auth),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VehicleMaintenanceTimeline(timeline: timeline),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Revisão'));
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceDetailPage), findsOneWidget);
  });

  testWidgets('provenance dots sit above filter chips in timeline card',
      (tester) async {
    final timeline = {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 2,
        'total_spent': 500,
      },
      'vehicle': {'brand': 'Mercedes-Benz', 'model': 'C 180'},
      'events': [
        {
          'type': 'maintenance',
          'id': 1,
          'label': 'Revisão',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': true,
        },
      ],
    };
    final provenanceStrip = [
      ProvenanceSegment(
        maintenanceId: 1,
        date: DateTime(2024, 6, 1),
        isVerified: true,
      ),
      ProvenanceSegment(
        maintenanceId: 2,
        date: DateTime(2025, 1, 1),
        isVerified: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleMaintenanceTimeline(
            timeline: timeline,
            verifiedFilter: null,
            onVerifiedFilterChanged: (_) {},
            provenanceStrip: provenanceStrip,
            maintenancesCount: 2,
            verifiedMaintenancesCount: 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance_strip_segment_0')), findsOneWidget);
    expect(find.byKey(const Key('provenance_filter_all')), findsOneWidget);

    final segmentTop = tester.getTopLeft(
      find.byKey(const Key('provenance_strip_segment_0')),
    );
    final filterTop = tester.getTopLeft(
      find.byKey(const Key('provenance_filter_all')),
    );
    expect(segmentTop.dy, lessThan(filterTop.dy));
  });

  testWidgets('shows only filter bar when provenance strip is empty',
      (tester) async {
    final timeline = {
      'summary': {
        'last_kilometers': 110000,
        'maintenance_count': 1,
        'total_spent': 500,
      },
      'vehicle': {'brand': 'VW', 'model': 'Gol'},
      'events': [
        {
          'type': 'maintenance',
          'id': 1,
          'label': 'Revisão',
          'date': '2024-06-01',
          'kilometers': 100000,
          'is_verified': true,
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleMaintenanceTimeline(
            timeline: timeline,
            verifiedFilter: null,
            onVerifiedFilterChanged: (_) {},
            provenanceStrip: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provenance_strip_segment_0')), findsNothing);
    expect(find.byKey(const Key('provenance_filter_all')), findsOneWidget);
  });
}
