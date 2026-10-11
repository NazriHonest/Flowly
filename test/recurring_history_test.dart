import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:flowly/features/recurring/domain/services/recurring_forecast_service.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'history contains only genuinely linked recurring transactions',
    () async {
      final fixture = await _Fixture.create();
      final database = fixture.database;
      await database.saveRecurringTransaction(
        RecurringTransaction(
          title: 'Rent',
          amountMinor: 50000,
          type: TransactionType.expense,
          category: 'Housing',
          accountId: fixture.accountId,
          frequency: 'monthly',
          startDate: DateTime(2026, 1, 1),
          nextOccurrence: DateTime(2026, 1, 1),
        ),
      );
      final schedule = (await database.recurringTransactions()).single;
      expect(
        await database.generateRecurringOccurrence(
          schedule,
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 1),
        ),
        isTrue,
      );
      expect(
        await database.generateRecurringOccurrence(
          schedule,
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 1),
        ),
        isFalse,
      );
      await database.generateRecurringOccurrence(
        schedule,
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );
      await database.saveTransaction(
        Transaction(
          amountMinor: 50000,
          type: TransactionType.expense,
          title: 'Rent',
          category: 'Housing',
          accountId: fixture.accountId,
          date: DateTime(2026, 3, 1),
        ),
      );

      var history = await database.recurringTransactionHistory(schedule.id!);
      expect(history, hasLength(2));
      expect(history.first.date, DateTime(2026, 2, 1));

      final edited = history.first;
      await database.saveTransaction(
        Transaction(
          id: edited.id,
          amountMinor: 52500,
          type: edited.type,
          title: edited.title,
          category: edited.category,
          accountId: edited.accountId,
          date: DateTime(2026, 2, 2),
          source: edited.source,
          status: edited.status,
        ),
      );
      history = await database.recurringTransactionHistory(schedule.id!);
      expect(history.first.amountMinor, 52500);
      expect(history.first.date, DateTime(2026, 2, 2));

      await database.deleteTransaction(history.first.id!);
      expect(
        await database.recurringTransactionHistory(schedule.id!),
        hasLength(1),
      );
      await fixture.dispose();
    },
  );

  test('pause and resume update only the persisted enabled flag', () async {
    final fixture = await _Fixture.create();
    await fixture.database.saveRecurringTransaction(
      RecurringTransaction(
        title: 'Internet',
        amountMinor: 7500,
        type: TransactionType.expense,
        category: 'Bills',
        accountId: fixture.accountId,
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 10),
        nextOccurrence: DateTime(2026, 1, 10),
        notes: 'Keep this note',
      ),
    );
    final original = (await fixture.database.recurringTransactions()).single;
    await fixture.database.setRecurringTransactionEnabled(original.id!, false);
    final paused = (await fixture.database.recurringTransactions()).single;
    expect(paused.enabled, isFalse);
    expect(paused.title, original.title);
    expect(paused.notes, original.notes);
    expect(paused.nextOccurrence, original.nextOccurrence);

    await fixture.database.setRecurringTransactionEnabled(original.id!, true);
    expect(
      (await fixture.database.recurringTransactions()).single.enabled,
      isTrue,
    );
    await fixture.dispose();
  });

  test(
    'viewing forecasts creates no transactions and archives stay out',
    () async {
      final fixture = await _Fixture.create();
      await fixture.database.saveRecurringTransaction(
        RecurringTransaction(
          title: 'Forecast only',
          amountMinor: 2500,
          type: TransactionType.expense,
          category: 'Bills',
          accountId: fixture.accountId,
          frequency: 'weekly',
          startDate: DateTime(2026, 1, 1),
          nextOccurrence: DateTime(2026, 1, 1),
        ),
      );
      final schedule = (await fixture.database.recurringTransactions()).single;
      expect(
        const RecurringForecastService().upcoming([
          schedule,
        ], from: DateTime(2026, 1, 1)),
        isNotEmpty,
      );
      final raw = await fixture.database.db;
      final countRows = await raw.rawQuery(
        'SELECT COUNT(*) AS transaction_count FROM transactions',
      );
      expect(countRows.single['transaction_count'], 0);

      await fixture.database.archiveRecurringTransaction(schedule.id!);
      expect(await fixture.database.recurringTransactions(), isEmpty);
      await fixture.dispose();
    },
  );
}

class _Fixture {
  _Fixture(this.directory, this.database, this.accountId);

  final Directory directory;
  final AppDatabase database;
  final int accountId;

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'spenflo-recurring-',
    );
    final database = AppDatabase.forTesting(
      '${directory.path}${Platform.pathSeparator}flowly.db',
    );
    final raw = await database.db;
    final accountId = await raw.insert('accounts', {
      'name': 'Checking',
      'opening_balance': 0,
      'color': 0xff079669,
      'icon': 0xe850,
      'type': 'bank',
      'currency': 'USD',
      'is_archived': 0,
    });
    return _Fixture(directory, database, accountId);
  }

  Future<void> dispose() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
