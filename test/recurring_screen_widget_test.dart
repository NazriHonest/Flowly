import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowly/core/theme/app_theme.dart';
import 'package:flowly/features/categories/domain/entities/category.dart';
import 'package:flowly/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:flowly/features/recurring/presentation/recurring_screen.dart';
import 'package:flowly/features/recurring/providers/recurring_provider.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('recurring forecast renders in ${mode.name} mode', (
      tester,
    ) async {
      final now = DateTime.now();
      final items = [
        RecurringTransaction(
          id: 1,
          title: 'A very long weekly household commitment title',
          amountMinor: 123456789,
          type: TransactionType.expense,
          category: 'Housing',
          accountId: 1,
          frequency: 'weekly',
          startDate: DateTime(now.year, now.month, now.day + 1),
          nextOccurrence: DateTime(now.year, now.month, now.day + 1),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recurringListProvider.overrideWith(
              (ref) => RecurringController(initialItems: items),
            ),
            recurringCategoriesProvider.overrideWithValue(const [
              Category(id: 1, name: 'Housing', icon: 0xe88a, color: 0xff079669),
            ]),
            recurringTodayProvider.overrideWith(
              (ref) => Stream<DateTime>.value(now),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(1.25),
              ),
              child: RecurringScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Next upcoming'), findsOneWidget);
      expect(find.text('Scheduled expenses'), findsOneWidget);
      expect(find.text('Scheduled income'), findsOneWidget);
      expect(find.text('Expected net'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Payments'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
