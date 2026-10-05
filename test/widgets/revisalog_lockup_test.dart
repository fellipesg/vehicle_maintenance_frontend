import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/theme/app_theme.dart';
import 'package:vehicle_maintenance/widgets/revisalog_lockup.dart';

OdometerMarkPainter markPainter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(RevisalogLockupHorizontal),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter! as OdometerMarkPainter;
}

void main() {
  testWidgets('light lockup draws a teal arc and a navy needle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: RevisalogLockupHorizontal(),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    final painter = markPainter(tester);
    expect(painter.arcColor, AppColors.teal);
    expect(painter.markColor, AppColors.navy);
  });

  testWidgets('dark lockup draws a white needle on the navy bar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: RevisalogLockupHorizontal(),
        ),
      ),
    );

    final painter = markPainter(tester);
    expect(painter.arcColor, AppColors.teal);
    expect(painter.markColor, Colors.white);
  });
}
