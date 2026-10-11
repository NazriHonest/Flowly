import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/core/database/migrations/migration_runner.dart';
import 'package:flowly/features/budgets/domain/entities/budget.dart';
import 'package:flowly/features/budgets/domain/entities/budget_history.dart';
import 'package:flowly/features/budgets/domain/services/budget_period_calculator.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('budget period calculations', () {
    test(
      'monthly, weekly and yearly ranges preserve established semantics',
      () {
        final now = DateTime(2026, 10, 10);
        final monthly = BudgetPeriodCalculator.current(
          _budget(period: 'monthly'),
          asOf: now,
        );
        final weekly = BudgetPeriodCalculator.current(
          _budget(period: 'weekly'),
          asOf: now,
        );
        final yearly = BudgetPeriodCalculator.current(
          _budget(period: 'yearly'),
          asOf: now,
        );

        expect(monthly.start, DateTime(2026, 10, 1));
        expect(monthly.end, DateTime(2026, 10, 31));
        expect(weekly.start, DateTime(2026, 10, 4));
        expect(weekly.end, DateTime(2026, 10, 10));
        expect(yearly.start, DateTime(2026, 1, 1));
        expect(yearly.end, DateTime(2026, 12, 31));
      },
    );

    test('history returns six chronological monthly periods', () {
      final periods = BudgetPeriodCalculator.recent(
        _budget(period: 'monthly'),
        6,
        asOf: DateTime(2026, 10, 10),
      );

      expect(periods, hasLength(6));
      expect(periods.first.start, DateTime(2026, 5, 1));
      expect(periods.last.end, DateTime(2026, 10, 31));
    });

    test('budget creation midway through a period clips the first range', () {
      final budget = Budget(
        name: 'Groceries',
        category: 'Groceries',
        amountMinor: 50000,
        period: 'monthly',
        startDate: DateTime(2026, 10, 15),
      );

      final period = BudgetPeriodCalculator.current(
        budget,
        asOf: DateTime(2026, 10, 20),
      );
      expect(period.start, DateTime(2026, 10, 15));
      expect(period.end, DateTime(2026, 10, 31));
    });
  });

  test('usage ratios cover zero, below, warning and over-budget values', () {
    BudgetHistoryPeriod period(int spent, int limit) => BudgetHistoryPeriod(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      label: 'October 2026',
      category: 'Groceries',
      spentMinor: spent,
      limitMinor: limit,
      transactions: const [],
      isCurrent: false,
    );

    expect(period(0, 0).ratio, 0);
    expect(period(1, 0).ratio, double.infinity);
    expect(period(25000, 50000).ratio, .5);
    expect(period(40000, 50000).ratio, .8);
    expect(period(60000, 50000).ratio, 1.2);
  });

  test('an unavailable historical limit never produces a comparison', () {
    final period = BudgetHistoryPeriod(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      label: 'September 2026',
      category: 'Groceries',
      spentMinor: 42000,
      limitMinor: null,
      transactions: const [],
      isCurrent: false,
    );

    expect(period.ratio, isNull);
  });

  test(
    'v18 migration preserves data and adds period-limit snapshots',
    () async {
      final temp = await Directory.systemTemp.createTemp('spenflo-budget-v18-');
      final path = '${temp.path}${Platform.pathSeparator}upgrade.db';
      final oldDatabase = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 17,
          onCreate: (database, _) async {
            for (final migration in MigrationRunner.migrations.where(
              (migration) => migration.version <= 17,
            )) {
              await migration.apply(database);
            }
            await database.insert('budgets', {
              'category': 'Groceries',
              'amount': 40000,
              'name': 'Groceries',
              'period': 'monthly',
              'start_date': '2026-07-01T00:00:00.000',
              'alert_threshold': .8,
              'is_archived': 0,
            });
          },
        ),
      );
      await oldDatabase.close();

      final appDatabase = AppDatabase.forTesting(path);
      final database = await appDatabase.db;
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='budget_period_limits'",
      );
      expect(tables, hasLength(1));
      expect(await appDatabase.budgets(), hasLength(1));
      expect(await appDatabase.budgetLimitSnapshots(1), isEmpty);

      await appDatabase.recordCurrentBudgetLimit(
        Budget(
          id: 1,
          name: 'Groceries',
          category: 'Groceries',
          amountMinor: 40000,
          period: 'monthly',
          startDate: DateTime(2026, 7, 1),
        ),
        asOf: DateTime(2026, 7, 15),
      );
      await appDatabase.recordCurrentBudgetLimit(
        Budget(
          id: 1,
          name: 'Groceries',
          category: 'Groceries',
          amountMinor: 50000,
          period: 'monthly',
          startDate: DateTime(2026, 7, 1),
        ),
        asOf: DateTime(2026, 8, 15),
      );
      final snapshots = await appDatabase.budgetLimitSnapshots(1);
      expect(snapshots, hasLength(2));
      expect(
        snapshots.singleWhere((item) => item.start.month == 7).amountMinor,
        40000,
      );
      expect(
        snapshots.singleWhere((item) => item.start.month == 8).amountMinor,
        50000,
      );

      await appDatabase.recordCurrentBudgetLimit(
        Budget(
          id: 1,
          name: 'Groceries',
          category: 'Groceries',
          amountMinor: 50000,
          period: 'monthly',
          startDate: DateTime(2026, 7, 1),
          archived: true,
        ),
        asOf: DateTime(2026, 9, 15),
      );
      expect(
        (await appDatabase.budgetLimitSnapshots(1))
            .singleWhere((item) => item.start.month == 9)
            .amountMinor,
        50000,
      );

      await appDatabase.close();
      await temp.delete(recursive: true);
    },
  );

  test('historical spending follows transaction edits and deletion', () async {
    final temp = await Directory.systemTemp.createTemp(
      'spenflo-budget-ledger-',
    );
    final path = '${temp.path}${Platform.pathSeparator}ledger.db';
    final database = AppDatabase.forTesting(path);
    final raw = await database.db;
    final accountId = await raw.insert('accounts', {
      'name': 'Cash',
      'opening_balance': 0,
      'color': 0xff079669,
      'icon': 0xe850,
      'type': 'cash',
      'currency': 'USD',
      'is_archived': 0,
    });
    expect(
      await database.budgetHistoryTransactions(
        category: 'Groceries',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
      isEmpty,
    );
    await database.saveTransaction(
      Transaction(
        amountMinor: 8500,
        type: TransactionType.expense,
        title: 'Market',
        category: 'Groceries',
        accountId: accountId,
        date: DateTime(2026, 7, 10),
      ),
    );
    var july = await database.budgetHistoryTransactions(
      category: 'Groceries',
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    expect(july.single.amountMinor, 8500);

    await database.saveTransaction(
      Transaction(
        id: july.single.id,
        amountMinor: 12000,
        type: TransactionType.expense,
        title: 'Market',
        category: 'Groceries',
        accountId: accountId,
        date: DateTime(2026, 8, 5),
      ),
    );
    july = await database.budgetHistoryTransactions(
      category: 'Groceries',
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final august = await database.budgetHistoryTransactions(
      category: 'Groceries',
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    expect(july, isEmpty);
    expect(august.single.amountMinor, 12000);

    await database.deleteTransaction(august.single.id!);
    expect(
      await database.budgetHistoryTransactions(
        category: 'Groceries',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      ),
      isEmpty,
    );
    await database.close();
    await temp.delete(recursive: true);
  });
}

Budget _budget({required String period}) => Budget(
  name: 'Groceries',
  category: 'Groceries',
  amountMinor: 50000,
  period: period,
  startDate: DateTime(2020),
);
