import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/widgets/load_more_button.dart';

void main() {
  testWidgets('taps call onPressed once', (tester) async {
    var taps = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoadMoreButton(
          isLoading: false,
          onPressed: () => taps++,
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('load_more_button')));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('shows a spinner and hides the button while loading',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoadMoreButton(
          isLoading: true,
          onPressed: () {},
        ),
      ),
    ));

    expect(find.byKey(const Key('load_more_progress')), findsOneWidget);
    expect(find.byKey(const Key('load_more_button')), findsNothing);
  });
}
