import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import 'dart:convert';

import '../../features/accounts/domain/entities/account.dart';
import '../../features/budgets/domain/entities/budget.dart';
import '../../features/categories/domain/entities/category.dart';
import '../../features/categorization/domain/services/categorization_service.dart';
import '../../features/goals/domain/entities/goal.dart';
import '../../features/recurring/domain/entities/recurring_transaction.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/sms_detection/domain/entities/sms_provider.dart';
import '../../features/transactions/domain/entities/transaction.dart';
import 'migrations/migration_runner.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  final _migrations = const MigrationRunner();
  Database? _database;

  Future<String> get databasePath async =>
      join(await getDatabasesPath(), 'flowly.db');

  /// Closes the current handle so a validated restore can safely replace it.
  Future<void> reopen() async {
    await _database?.close();
    _database = null;
    await db;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get db async => _database ??= await openDatabase(
    join(await getDatabasesPath(), 'flowly.db'),
    version: 15,
    onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
    onCreate: (database, _) => _migrations.create(database),
    onUpgrade: (database, oldVersion, _) =>
        _migrations.run(database, from: oldVersion),
  );

  Future<List<Transaction>> transactions() async => (await db)
      .query('transactions', orderBy: 'transaction_date DESC')
      .then((rows) => rows.map(_transaction).toList());
  Future<List<Account>> accounts() async => (await db)
      .query('accounts', where: 'is_archived=0')
      .then(
        (rows) => rows
            .map(
              (m) => Account(
                id: m['id'] as int,
                name: m['name'] as String,
                openingBalanceMinor: m['opening_balance'] as int,
                color: m['color'] as int,
                icon: m['icon'] as int? ?? 0xe850,
                type: m['type'] as String,
                currency: m['currency'] as String,
                providerId: m['provider_id'] as int?,
                archived: (m['is_archived'] as int) == 1,
              ),
            )
            .toList(),
      );
  Future<List<Budget>> budgets() async => (await db)
      .query('budgets', where: 'is_archived=0')
      .then(
        (rows) => rows
            .map(
              (m) => Budget(
                id: m['id'] as int,
                name: (m['name'] as String?)?.isNotEmpty == true
                    ? m['name'] as String
                    : m['category'] as String,
                category: m['category'] as String,
                amountMinor: m['amount'] as int,
                period: m['period'] as String,
                startDate: DateTime.tryParse(m['start_date'] as String? ?? ''),
                alertThreshold: (m['alert_threshold'] as num).toDouble(),
                archived: (m['is_archived'] as int) == 1,
              ),
            )
            .toList(),
      );
  Future<List<Category>> categories({
    bool includeArchived = false,
  }) async => (await db)
      .query(
        'categories',
        where: includeArchived ? null : 'is_archived=0',
        orderBy: 'name COLLATE NOCASE',
      )
      .then(
        (rows) => rows
            .map(
              (m) => Category(
                id: m['id'] as int,
                name: m['name'] as String,
                icon: m['icon'] as int,
                color: m['color'] as int,
                type: m['type'] as String,
                archived: (m['is_archived'] as int) == 1,
                createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
                updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? ''),
              ),
            )
            .toList(),
      );
  Future<List<Goal>> goals() async => (await db)
      .query('goals', orderBy: 'target_date ASC')
      .then(
        (rows) => rows
            .map(
              (m) => Goal(
                id: m['id'] as int,
                name: m['name'] as String,
                targetMinor: m['target_amount'] as int,
                currentMinor: m['current_amount'] as int,
                targetDate: DateTime.tryParse(
                  m['target_date'] as String? ?? '',
                ),
                accountId: m['account_id'] as int?,
              ),
            )
            .toList(),
      );

  Transaction _transaction(Map<String, Object?> m) => Transaction(
    id: m['id'] as int,
    amountMinor: m['amount'] as int,
    type: TransactionType.values.byName(m['type'] as String),
    title: m['title'] as String,
    category: m['category'] as String,
    accountId: m['account_id'] as int,
    destinationAccountId: m['destination_account_id'] as int?,
    date: DateTime.parse(m['transaction_date'] as String),
    source: TransactionSource.values.byName(m['source'] as String),
    status: ReviewStatus.values.byName(m['status'] as String),
    notes: m['notes'] as String,
    providerTransactionAt: DateTime.tryParse(
      m['provider_transaction_at'] as String? ?? '',
    ),
    smsReceivedAt: DateTime.tryParse(m['sms_received_at'] as String? ?? ''),
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
  );

  Future<void> saveTransaction(Transaction t) async {
    if (t.isTransfer &&
        (t.destinationAccountId == null ||
            t.destinationAccountId == t.accountId)) {
      throw ArgumentError('A transfer requires two different accounts.');
    }
    final database = await db;
    final existingCreatedAt = t.id == null
        ? null
        : (await database.query(
                'transactions',
                columns: ['created_at'],
                where: 'id=?',
                whereArgs: [t.id],
              )).firstOrNull?['created_at']
              as String?;
    final values = {
      'amount': t.amountMinor,
      'type': t.type.name,
      'title': t.title,
      'category': t.category,
      'account_id': t.accountId,
      'destination_account_id': t.destinationAccountId,
      'transaction_date': t.date.toIso8601String(),
      'source': t.source.name,
      'status': t.status.name,
      'notes': t.notes,
      'provider_transaction_at': t.providerTransactionAt
          ?.toUtc()
          .toIso8601String(),
      'sms_received_at': t.smsReceivedAt?.toUtc().toIso8601String(),
      'created_at':
          t.createdAt?.toUtc().toIso8601String() ??
          existingCreatedAt ??
          DateTime.now().toUtc().toIso8601String(),
    };
    if (t.id == null) {
      await database.insert('transactions', values);
    } else {
      await database.update(
        'transactions',
        values,
        where: 'id=?',
        whereArgs: [t.id],
      );
    }
  }

  Future<void> deleteTransaction(int id) async =>
      (await db).delete('transactions', where: 'id=?', whereArgs: [id]);

  /// Atomically rejects a duplicate fingerprint or saves both its normalized
  /// transaction and fingerprint. No raw SMS data enters this operation.
  Future<bool> saveDetectedTransaction(
    Transaction t,
    String fingerprint,
  ) async {
    final database = await db;
    return database.transaction((txn) async {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM transaction_fingerprints WHERE fingerprint=?',
              [fingerprint],
            ),
          ) ??
          0;
      if (count > 0) return false;
      final id = await txn.insert('transactions', {
        'amount': t.amountMinor,
        'type': t.type.name,
        'title': t.title,
        'category': t.category,
        'account_id': t.accountId,
        'destination_account_id': t.destinationAccountId,
        'transaction_date': t.date.toIso8601String(),
        'source': t.source.name,
        'status': t.status.name,
        'notes': t.notes,
        'provider_transaction_at': t.providerTransactionAt
            ?.toUtc()
            .toIso8601String(),
        'sms_received_at': t.smsReceivedAt?.toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.insert('transaction_fingerprints', {
        'fingerprint': fingerprint,
        'transaction_id': id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    });
  }

  Future<bool> hasFingerprint(String fingerprint) async =>
      (Sqflite.firstIntValue(
            await (await db).rawQuery(
              'SELECT COUNT(*) FROM transaction_fingerprints WHERE fingerprint=?',
              [fingerprint],
            ),
          ) ??
          0) >
      0;

  /// Converts two opposite SMS records into one transfer for accounting while
  /// keeping both original normalized records in a reversible snapshot.
  Future<void> linkTransfer({
    required int outgoingTransactionId,
    required int incomingTransactionId,
  }) async {
    if (outgoingTransactionId == incomingTransactionId) {
      throw ArgumentError('A transfer requires two different transactions.');
    }
    final database = await db;
    await database.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id IN (?, ?)',
        whereArgs: [outgoingTransactionId, incomingTransactionId],
      );
      if (rows.length != 2) {
        throw StateError('Transfer transactions not found.');
      }
      final byId = {for (final row in rows) row['id'] as int: row};
      final outgoing = byId[outgoingTransactionId]!;
      final incoming = byId[incomingTransactionId]!;
      if (outgoing['type'] != TransactionType.expense.name ||
          incoming['type'] != TransactionType.income.name ||
          outgoing['status'] != ReviewStatus.confirmed.name ||
          incoming['status'] != ReviewStatus.confirmed.name ||
          outgoing['amount'] != incoming['amount'] ||
          outgoing['account_id'] == incoming['account_id']) {
        throw ArgumentError('Transactions are not a compatible transfer pair.');
      }
      final currencies = await txn.query(
        'accounts',
        columns: ['id', 'currency'],
        where: 'id IN (?, ?)',
        whereArgs: [outgoing['account_id'], incoming['account_id']],
      );
      if (currencies.length != 2 ||
          currencies[0]['currency'] != currencies[1]['currency']) {
        throw ArgumentError('Transfers must use accounts with the same currency.');
      }
      await txn.insert('transfer_reconciliations', {
        'outgoing_transaction_id': outgoingTransactionId,
        'incoming_transaction_id': incomingTransactionId,
        'outgoing_snapshot': jsonEncode(outgoing),
        'incoming_snapshot': jsonEncode(incoming),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      await txn.update(
        'transactions',
        {
          'type': TransactionType.transfer.name,
          'destination_account_id': incoming['account_id'],
          'title': 'Transfer',
          'category': 'Transfer',
          'status': ReviewStatus.confirmed.name,
        },
        where: 'id=?',
        whereArgs: [outgoingTransactionId],
      );
      await txn.update(
        'transactions',
        {'status': ReviewStatus.ignored.name},
        where: 'id=?',
        whereArgs: [incomingTransactionId],
      );
    });
  }

  Future<bool> isReconciledTransfer(int transactionId) async =>
      (Sqflite.firstIntValue(
            await (await db).rawQuery(
              'SELECT COUNT(*) FROM transfer_reconciliations WHERE outgoing_transaction_id=?',
              [transactionId],
            ),
          ) ??
          0) >
      0;

  Future<void> unlinkTransfer(int outgoingTransactionId) async {
    final database = await db;
    await database.transaction((txn) async {
      final link = (await txn.query(
        'transfer_reconciliations',
        where: 'outgoing_transaction_id=?',
        whereArgs: [outgoingTransactionId],
      )).firstOrNull;
      if (link == null) throw StateError('Transfer link not found.');
      Future<void> restore(String key) async {
        final snapshot = Map<String, dynamic>.from(
          jsonDecode(link[key] as String),
        );
        final id = snapshot.remove('id') as int;
        await txn.update(
          'transactions',
          snapshot,
          where: 'id=?',
          whereArgs: [id],
        );
      }

      await restore('outgoing_snapshot');
      await restore('incoming_snapshot');
      await txn.delete(
        'transfer_reconciliations',
        where: 'outgoing_transaction_id=?',
        whereArgs: [outgoingTransactionId],
      );
    });
  }

  Future<void> saveAccount(Account a) async {
    final values = {
      'name': a.name.trim(),
      'opening_balance': a.openingBalanceMinor,
      'color': a.color,
      'icon': a.icon,
      'type': a.type,
      'currency': a.currency,
      'provider_id': a.providerId,
      'is_archived': a.archived ? 1 : 0,
    };
    final database = await db;
    if (a.id == null) {
      await database.insert('accounts', values);
    } else {
      await database.update(
        'accounts',
        values,
        where: 'id=?',
        whereArgs: [a.id],
      );
    }
  }

  Future<void> archiveAccount(int id) async => (await db).update(
    'accounts',
    {'is_archived': 1},
    where: 'id=?',
    whereArgs: [id],
  );
  Future<void> saveBudget(Budget b) async {
    final values = {
      'name': b.name,
      'category': b.category,
      'amount': b.amountMinor,
      'period': b.period,
      'start_date': (b.startDate ?? DateTime.now()).toIso8601String(),
      'alert_threshold': b.alertThreshold,
      'is_archived': b.archived ? 1 : 0,
    };
    final database = await db;
    if (b.id == null) {
      await database.insert('budgets', values);
    } else {
      await database.update(
        'budgets',
        values,
        where: 'id=?',
        whereArgs: [b.id],
      );
    }
  }

  Future<void> archiveBudget(int id) async => (await db).update(
    'budgets',
    {'is_archived': 1},
    where: 'id=?',
    whereArgs: [id],
  );
  Future<void> saveCategory(Category category) async {
    final now = DateTime.now().toIso8601String();
    final values = {
      'name': category.name.trim(),
      'icon': category.icon,
      'color': category.color,
      'type': category.type,
      'is_archived': category.archived ? 1 : 0,
      'updated_at': now,
    };
    final database = await db;
    if (category.id == null) {
      await database.insert('categories', {...values, 'created_at': now});
    } else {
      await database.update(
        'categories',
        values,
        where: 'id=?',
        whereArgs: [category.id],
      );
    }
  }

  Future<void> archiveCategory(int id) async => (await db).update(
    'categories',
    {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
    where: 'id=?',
    whereArgs: [id],
  );
  Future<void> saveGoal(Goal goal) async {
    final values = {
      'name': goal.name,
      'target_amount': goal.targetMinor,
      'current_amount': goal.currentMinor,
      'target_date': goal.targetDate?.toIso8601String(),
      'account_id': goal.accountId,
    };
    final database = await db;
    if (goal.id == null) {
      await database.insert('goals', values);
    } else {
      await database.update(
        'goals',
        values,
        where: 'id=?',
        whereArgs: [goal.id],
      );
    }
  }

  Future<void> contributeToGoal(int id, int amount) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE goals SET current_amount=current_amount+? WHERE id=?',
        [amount, id],
      );
      await txn.insert('goal_contributions', {
        'goal_id': id,
        'amount': amount,
        'contributed_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> goalContributions(int goalId) async =>
      (await db).query(
        'goal_contributions',
        where: 'goal_id=?',
        whereArgs: [goalId],
        orderBy: 'contributed_at DESC',
      );

  Future<void> deleteGoal(int id) async =>
      (await db).delete('goals', where: 'id=?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> merchantRules() async =>
      (await db).query('merchant_rules', orderBy: 'normalized_merchant');
  Future<void> saveMerchantRule(String merchant, String category) async =>
      (await db).insert('merchant_rules', {
        'normalized_merchant': normalizeMerchant(merchant),
        'category': category,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteMerchantRule(int id) async =>
      (await db).delete('merchant_rules', where: 'id=?', whereArgs: [id]);
  Future<List<RecurringTransaction>> recurringTransactions() async => (await db)
      .query(
        'recurring_transactions',
        where: 'is_archived=0',
        orderBy: 'next_occurrence',
      )
      .then(
        (rows) => rows
            .map(
              (row) => RecurringTransaction(
                id: row['id'] as int,
                title: row['title'] as String,
                amountMinor: row['amount'] as int,
                type: TransactionType.values.byName(row['type'] as String),
                category: row['category'] as String,
                accountId: row['account_id'] as int,
                frequency: row['frequency'] as String,
                nextOccurrence: DateTime.parse(
                  row['next_occurrence'] as String,
                ),
                endDate: DateTime.tryParse(row['end_date'] as String? ?? ''),
                startDate: DateTime.tryParse(
                  row['start_date'] as String? ?? '',
                ),
                notes: row['notes'] as String? ?? '',
                enabled: (row['is_enabled'] as int) == 1,
              ),
            )
            .toList(),
      );
  Future<void> saveRecurringTransaction(RecurringTransaction item) async {
    final values = {
      'title': item.title,
      'amount': item.amountMinor,
      'type': item.type.name,
      'category': item.category,
      'account_id': item.accountId,
      'frequency': item.frequency,
      'next_occurrence': item.nextOccurrence.toIso8601String(),
      'end_date': item.endDate?.toIso8601String(),
      'start_date': item.startDate?.toIso8601String(),
      'notes': item.notes,
      'is_enabled': item.enabled ? 1 : 0,
    };
    final database = await db;
    if (item.id == null) {
      await database.insert('recurring_transactions', values);
    } else {
      await database.update(
        'recurring_transactions',
        values,
        where: 'id=?',
        whereArgs: [item.id],
      );
    }
  }

  Future<void> archiveRecurringTransaction(int id) async => (await db).update(
    'recurring_transactions',
    {'is_archived': 1},
    where: 'id=?',
    whereArgs: [id],
  );
  Future<bool> generateRecurringOccurrence(
    RecurringTransaction item,
    DateTime occurrence,
    DateTime next,
  ) async {
    final database = await db;
    return database.transaction((txn) async {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM recurring_occurrences WHERE recurring_id=? AND occurrence_date=?',
              [item.id, occurrence.toIso8601String()],
            ),
          ) ??
          0;
      if (count > 0) return false;
      final transactionId = await txn.insert('transactions', {
        'amount': item.amountMinor,
        'type': item.type.name,
        'title': item.title,
        'category': item.category,
        'account_id': item.accountId,
        'destination_account_id': null,
        'transaction_date': occurrence.toIso8601String(),
        'source': TransactionSource.recurring.name,
        'status': ReviewStatus.confirmed.name,
        'notes': '',
      });
      await txn.insert('recurring_occurrences', {
        'recurring_id': item.id,
        'occurrence_date': occurrence.toIso8601String(),
        'transaction_id': transactionId,
      });
      await txn.update(
        'recurring_transactions',
        {'next_occurrence': next.toIso8601String()},
        where: 'id=?',
        whereArgs: [item.id],
      );
      return true;
    });
  }

  Future<List<AppNotification>> notifications() async => (await db)
      .query('notifications', orderBy: 'created_at DESC')
      .then(
        (rows) => rows
            .map(
              (row) => AppNotification(
                id: row['id'] as int,
                title: row['title'] as String,
                body: row['body'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
                isRead: (row['is_read'] as int) == 1,
              ),
            )
            .toList(),
      );

  Future<void> createNotification(String title, String body) async =>
      (await db).insert('notifications', {
        'title': title,
        'body': body,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': 0,
      });

  Future<void> markNotificationRead(int id) async => (await db).update(
    'notifications',
    {'is_read': 1},
    where: 'id=?',
    whereArgs: [id],
  );
  Future<void> markAllNotificationsRead() async =>
      (await db).update('notifications', {'is_read': 1});
  Future<void> deleteNotification(int id) async =>
      (await db).delete('notifications', where: 'id=?', whereArgs: [id]);
  Future<void> clearNotifications() async => (await db).delete('notifications');

  Future<List<SmsProvider>> smsProviders() async => (await db)
      .query('sms_providers', orderBy: 'name COLLATE NOCASE')
      .then(
        (rows) => rows
            .map(
              (row) => SmsProvider(
                id: row['id'] as int,
                name: row['name'] as String,
                senderAliases: ((row['sender_aliases'] as String?) ?? '')
                    .split('\n')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList(),
                enabled: (row['is_enabled'] as int) == 1,
              ),
            )
            .toList(),
      );

  Future<void> saveSmsProvider(SmsProvider provider) async {
    final values = {
      'name': provider.name.trim(),
      'sender_aliases': provider.senderAliases
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join('\n'),
      'is_enabled': provider.enabled ? 1 : 0,
    };
    if (provider.id == null) {
      await (await db).insert('sms_providers', values);
    } else {
      await (await db).update(
        'sms_providers',
        values,
        where: 'id=?',
        whereArgs: [provider.id],
      );
    }
  }

  Future<List<ProviderAccountMapping>> providerAccountMappings() async =>
      (await db)
          .query('provider_account_mappings')
          .then(
            (rows) => rows
                .map(
                  (row) => ProviderAccountMapping(
                    id: row['id'] as int,
                    providerId: row['provider_id'] as int,
                    accountId: row['account_id'] as int,
                  ),
                )
                .toList(),
          );

  Future<void> setProviderAccountMapping(int providerId, int accountId) async {
    await (await db).insert('provider_account_mappings', {
      'provider_id': providerId,
      'account_id': accountId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeProviderAccountMapping(int id) async => (await db).delete(
    'provider_account_mappings',
    where: 'id=?',
    whereArgs: [id],
  );
}
