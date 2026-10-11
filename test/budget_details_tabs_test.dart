import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowly/features/budgets/presentation/budgets_screen.dart';

void main() {
  testWidgets('budget details switches between Overview and History', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: Column(
              children: [
                BudgetDetailsSegmentedControl(
                  selected: selected,
                  onChanged: (value) => update(() => selected = value),
                ),
                Text(selected == 0 ? 'Overview content' : 'History content'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Overview content'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget-history-tab')));
    await tester.pumpAndSettle();
    expect(find.text('History content'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('budget-overview-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Overview content'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'budget tabs render in ${brightness.name} mode at larger text size',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.4),
              ),
              child: Scaffold(
                body: BudgetDetailsSegmentedControl(
                  selected: 0,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
      },
    );
  }
}
