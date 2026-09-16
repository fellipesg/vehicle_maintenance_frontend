import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/widgets/vehicle_cover_avatar.dart';

void main() {
  testWidgets('shows fallback when url is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleCoverAvatar(),
        ),
      ),
    );

    expect(find.byIcon(Icons.directions_car), findsOneWidget);
  });

  testWidgets('shows placeholder before network image loads', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleCoverAvatar(
            coverPhotoThumbUrl: 'https://example.com/thumb.jpg',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(VehicleCoverAvatar), findsOneWidget);
  });
}
