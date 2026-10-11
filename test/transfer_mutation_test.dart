import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/accounts/domain/entities/account.dart';
import 'package:flowly/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory directory;
  late AppDatabase database;
  late Account source;
  late Account destination;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flowly-transfer-edit-');
    database = AppDatabase.forTesting(
      '${directory.path}${Platform.pathSeparator}flowly.db',
    );
    await database.saveAccount(
      const Account(
        name: 'Source',
        openingBalanceMinor: 10000,
        currency: 'USD',
      ),
    );
    await database.saveAccount(
      const Account(
        name: 'Destination',
        openingBalanceMinor: 5000,
        currency: 'USD',
      ),
    );
    final accounts = await database.accounts();
    source = accounts.firstWhere((item) => item.name == 'Source');
    destination = accounts.firstWhere((item) => item.name == 'Destination');
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'creating, editing and deleting a transfer keeps both balances correct',
    () async {
      await database.saveTransaction(
        Transaction(
          amountMinor: 2000,
          type: TransactionType.transfer,
          title: 'Transfer',
          category: 'Transfer',
          accountId: source.id!,
          destinationAccountId: destination.id,
          date: DateTime.utc(2026, 10, 11),
        ),
      );

      var transactions = await database.transactions();
      var transfer = transactions.single;
      expect(AccountBalanceCalculator.current(source, transactions), 8000);
      expect(AccountBalanceCalculator.current(destination, transactions), 7000);

      await database.saveTransaction(
        Transaction(
          id: transfer.id,
          amountMinor: 3000,
          type: TransactionType.transfer,
          title: transfer.title,
          category: transfer.category,
          accountId: source.id!,
          destinationAccountId: destination.id,
          date: transfer.date,
        ),
      );

      transactions = await database.transactions();
      transfer = transactions.single;
      expect(AccountBalanceCalculator.current(source, transactions), 7000);
      expect(AccountBalanceCalculator.current(destination, transactions), 8000);

      await database.deleteTransaction(transfer.id!);
      transactions = await database.transactions();
      expect(AccountBalanceCalculator.current(source, transactions), 10000);
      expect(AccountBalanceCalculator.current(destination, transactions), 5000);
    },
  );

  test(
    'invalid transfer combinations are rejected before persistence',
    () async {
      final invalid = Transaction(
        amountMinor: 1000,
        type: TransactionType.transfer,
        title: 'Transfer',
        category: 'Transfer',
        accountId: source.id!,
        destinationAccountId: source.id,
        date: DateTime.utc(2026, 10, 11),
      );

      await expectLater(database.saveTransaction(invalid), throwsArgumentError);
      expect(await database.transactions(), isEmpty);
    },
  );
}
