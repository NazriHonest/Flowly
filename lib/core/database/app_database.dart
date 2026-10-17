import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import 'dart:convert';
import 'dart:developer' as developer;

import '../../features/accounts/domain/entities/account.dart';
import '../../features/budgets/domain/entities/budget.dart';
import '../../features/budgets/domain/entities/budget_history.dart';
import '../../features/budgets/domain/services/budget_period_calculator.dart';
import '../../features/categories/domain/entities/category.dart';
import '../../features/categorization/domain/services/categorization_service.dart';
import '../../features/goals/domain/entities/goal.dart';
import '../../features/recurring/domain/entities/recurring_transaction.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/sms_detection/domain/entities/sms_provider.dart';
import '../../features/sms_detection/domain/entities/sms_transfer_observation.dart';
import '../../features/sms_detection/domain/entities/transaction_candidate.dart';
import '../../features/transactions/domain/entities/transaction.dart';
import '../../features/transactions/domain/entities/transfer_candidate.dart';
import '../../features/transactions/domain/services/transfer_reconciliation_service.dart';
import 'migrations/migration_runner.dart';

class AppDatabase {
  static const schemaVersion = 19;
  AppDatabase._({this.databasePathOverride});
  static final instance = AppDatabase._();
  factory AppDatabase.forTesting(String databasePath) =>
      AppDatabase._(databasePathOverride: databasePath);
  final String? databasePathOverride;
  final _migrations = const MigrationRunner();
  Database? _database;

  Future<String> get databasePath async =>
      databasePathOverride ?? join(await getDatabasesPath(), 'flowly.db');

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
    await databasePath,
    version: schemaVersion,
    onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
    onCreate: (database, _) => _migrations.create(database),
    onUpgrade: (database, oldVersion, _) =>
        _migrations.run(database, from: oldVersion),
  );

  Future<List<Transaction>> transactions() async => (await db)
      .query(
        'transactions',
        orderBy: 'transaction_date DESC, created_at DESC, id DESC',
      )
      .then((rows) => rows.map(_transaction).toList());

  Future<List<Account>> accounts({bool includeArchived = false}) async =>
      (await db)
          .query('accounts', where: includeArchived ? null : 'is_archived=0')
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
    if (t.amountMinor <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    if (t.isTransfer &&
        (t.destinationAccountId == null ||
            t.destinationAccountId == t.accountId)) {
      throw ArgumentError('A transfer requires two different accounts.');
    }
    final database = await db;
    if (t.isTransfer) {
      final accounts = await database.query(
        'accounts',
        columns: const ['id', 'currency'],
        where: 'id IN (?, ?)',
        whereArgs: [t.accountId, t.destinationAccountId],
      );
      if (accounts.length != 2 ||
          accounts[0]['currency'] != accounts[1]['currency']) {
        throw ArgumentError(
          'Transfers require two existing accounts with the same currency.',
        );
      }
    }
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

  Future<void> deleteTransaction(int id) async {
    final database = await db;
    await database.transaction((txn) async {
      final observations = await txn.query(
        'sms_transfer_observations',
        columns: ['fingerprint'],
        where: 'transaction_id=?',
        whereArgs: [id],
      );
      for (final observation in observations) {
        await txn.delete(
          'transaction_fingerprints',
          where: 'fingerprint=?',
          whereArgs: [observation['fingerprint']],
        );
      }
      await txn.update(
        'sms_transfer_observations',
        {
          'transaction_id': null,
          'status': SmsTransferObservationStatus.rejected.name,
        },
        where: 'transaction_id=?',
        whereArgs: [id],
      );
      await txn.delete('transactions', where: 'id=?', whereArgs: [id]);
    });
  }

  /// Atomically rejects a duplicate fingerprint or saves both its normalized
  /// transaction and fingerprint. No raw SMS data enters this operation.
  Future<bool> saveDetectedTransaction(
    Transaction t,
    String fingerprint,
  ) async {
    final database = await db;
    late final bool saved;
    try {
      saved = await database.transaction((txn) async {
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
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) return false;
      rethrow;
    }
    if (saved) {
      final row = (await database.query(
        'transaction_fingerprints',
        columns: ['transaction_id'],
        where: 'fingerprint=?',
        whereArgs: [fingerprint],
      )).firstOrNull;
      try {
        await reconcileDetectedTransaction(row?['transaction_id'] as int?);
      } catch (error, stack) {
        // Saving the normalized financial record is primary. Reconciliation
        // can be retried later and must never discard a successfully saved SMS.
        developer.log(
          'Transfer reconciliation deferred after persistence.',
          name: 'flowly.reconciliation',
          error: error,
          stackTrace: stack,
        );
      }
    }
    return saved;
  }

  /// Evaluates a newly persisted SMS record without ever using amount alone.
  /// Strong, unique matches additionally require both accounts to have an
  /// explicit provider mapping; all other compatible evidence is retained as
  /// a possible transfer for the user to inspect after restart.
  Future<void> reconcileDetectedTransaction(int? transactionId) async {
    if (transactionId == null) return;
    final database = await db;
    final rows = await database.query('transactions');
    final items = rows.map(_transaction).toList();
    final seed = items.where((item) => item.id == transactionId).firstOrNull;
    if (seed == null ||
        (seed.source != TransactionSource.smsLive &&
            seed.source != TransactionSource.smsImport) ||
        seed.status != ReviewStatus.confirmed) {
      return;
    }
    final ownedAccounts = await accounts();
    final currencies = {
      for (final account in ownedAccounts) account.id!: account.currency,
    };
    final mappings = await providerAccountMappings();
    final mappedAccounts = mappings.map((mapping) => mapping.accountId).toSet();
    final service = TransferReconciliationService();
    final outgoing = seed.type == TransactionType.expense ? seed : null;
    final matches = outgoing == null
        ? items
              .where((item) => item.type == TransactionType.expense)
              .expand(
                (item) => service.candidatesFor(
                  outgoing: item,
                  transactions: [seed],
                  outgoingCurrency: currencies[item.accountId] ?? '',
                  currencyForAccount: (id) => currencies[id] ?? '',
                ),
              )
              .toList()
        : service.candidatesFor(
            outgoing: outgoing,
            transactions: items,
            outgoingCurrency: currencies[outgoing.accountId] ?? '',
            currencyForAccount: (id) => currencies[id] ?? '',
          );
    final relevant = matches
        .where(
          (match) =>
              match.outgoing.id == transactionId ||
              match.incoming.id == transactionId,
        )
        .toList();
    final strong = relevant
        .where((match) => match.confidence == TransferMatchConfidence.strong)
        .toList();
    final providerMapped = strong
        .where(
          (match) =>
              mappedAccounts.contains(match.outgoing.accountId) &&
              mappedAccounts.contains(match.incoming.accountId),
        )
        .toList();
    if (providerMapped.length == 1) {
      final match = providerMapped.single;
      await database.insert('transfer_candidates', {
        'outgoing_transaction_id': match.outgoing.id,
        'incoming_transaction_id': match.incoming.id,
        'confidence': match.confidence.name,
        'status': TransferCandidateStatus.possible.name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await linkTransfer(
        outgoingTransactionId: match.outgoing.id!,
        incomingTransactionId: match.incoming.id!,
      );
      return;
    }
    for (final match in relevant) {
      await database.insert('transfer_candidates', {
        'outgoing_transaction_id': match.outgoing.id,
        'incoming_transaction_id': match.incoming.id,
        'confidence': match.confidence.name,
        'status': 'possible',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<bool> hasFingerprint(String fingerprint) async =>
      (Sqflite.firstIntValue(
                await (await db).rawQuery(
                  'SELECT COUNT(*) FROM transaction_fingerprints WHERE fingerprint=?',
                  [fingerprint],
                ),
              ) ??
              0) >
          0 ||
      (Sqflite.firstIntValue(
                await (await db).rawQuery(
                  'SELECT COUNT(*) FROM sms_transfer_observations WHERE fingerprint=?',
                  [fingerprint],
                ),
              ) ??
              0) >
          0;

  /// Persists privacy-safe transfer evidence and creates/attaches exactly one
  /// canonical transfer when the counterpart is unambiguous.
  Future<SmsTransferSaveOutcome> saveInternalTransferObservation({
    required TransactionCandidate candidate,
    required int providerId,
    required int mappedAccountId,
    required int? linkedAccountId,
    required TransactionSource source,
    required DateTime smsReceivedAt,
    required String fingerprint,
  }) async {
    final direction = candidate.transferDirection;
    if (candidate.semantics != CandidateSemantics.internalTransfer ||
        direction == null) {
      throw ArgumentError('An internal-transfer observation is required.');
    }
    final database = await db;
    try {
      return await database.transaction((txn) async {
        final duplicateObservation =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM sms_transfer_observations WHERE fingerprint=?',
                [fingerprint],
              ),
            ) ??
            0;
        final duplicateTransaction =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM transaction_fingerprints WHERE fingerprint=?',
                [fingerprint],
              ),
            ) ??
            0;
        if (duplicateObservation > 0 || duplicateTransaction > 0) {
          return SmsTransferSaveOutcome.duplicate;
        }

        final now = DateTime.now().toUtc().toIso8601String();
        Map<String, Object?> observationValues({
          int? transactionId,
          String status = 'pending',
        }) => {
          'transaction_id': transactionId,
          'provider_id': providerId,
          'mapped_account_id': mappedAccountId,
          'linked_account_id': linkedAccountId,
          'direction': direction.name,
          'amount': candidate.amountMinor,
          'currency': candidate.currency.toUpperCase(),
          'account_hint_hash': candidate.accountHintHash,
          'provider_transaction_at': candidate.providerTransactionAt
              ?.toUtc()
              .toIso8601String(),
          'sms_received_at': smsReceivedAt.toUtc().toIso8601String(),
          'source': source.name,
          'fingerprint': fingerprint,
          'status': status,
          'created_at': now,
        };

        Future<void> attachTo(int transactionId) async {
          await txn.insert(
            'sms_transfer_observations',
            observationValues(transactionId: transactionId, status: 'attached'),
          );
          await txn.insert('transaction_fingerprints', {
            'fingerprint': fingerprint,
            'transaction_id': transactionId,
            'created_at': now,
          });
        }

        bool closeEnough(String raw) =>
            smsReceivedAt
                .toUtc()
                .difference(DateTime.parse(raw).toUtc())
                .abs() <=
            const Duration(hours: 2);
        bool compatibleHint(Object? raw) =>
            candidate.accountHintHash == null ||
            raw == null ||
            raw == candidate.accountHintHash;

        int? sourceAccountId;
        int? destinationAccountId;
        final opposite = direction == TransferObservationDirection.outgoing
            ? TransferObservationDirection.incoming
            : TransferObservationDirection.outgoing;
        final attachedEvidence = await txn.query(
          'sms_transfer_observations',
          where: 'status=? AND direction=? AND amount=? AND currency=? AND mapped_account_id<>?',
          whereArgs: [
            SmsTransferObservationStatus.attached.name,
            opposite.name,
            candidate.amountMinor,
            candidate.currency.toUpperCase(),
            mappedAccountId,
          ],
        );
        final compatibleAttached = <Map<String, Object?>>[];
        for (final evidence in attachedEvidence) {
          if (!closeEnough(evidence['sms_received_at'] as String) ||
              !compatibleHint(evidence['account_hint_hash'])) {
            continue;
          }
          final otherMapped = evidence['mapped_account_id'] as int;
          final sharedHint =
              candidate.accountHintHash != null &&
              evidence['account_hint_hash'] == candidate.accountHintHash;
          final configuredRelationship =
              linkedAccountId == otherMapped ||
              evidence['linked_account_id'] == mappedAccountId;
          if (!sharedHint && !configuredRelationship) continue;
          final transaction = (await txn.query(
            'transactions',
            where: 'id=? AND type=? AND status=?',
            whereArgs: [
              evidence['transaction_id'],
              TransactionType.transfer.name,
              ReviewStatus.confirmed.name,
            ],
          )).firstOrNull;
          if (transaction == null) continue;
          final expectedSource =
              direction == TransferObservationDirection.outgoing
              ? mappedAccountId
              : otherMapped;
          final expectedDestination =
              direction == TransferObservationDirection.outgoing
              ? otherMapped
              : mappedAccountId;
          if (transaction['account_id'] == expectedSource &&
              transaction['destination_account_id'] == expectedDestination) {
            compatibleAttached.add(evidence);
          }
        }
        final attachedTransactionIds = compatibleAttached
            .map((row) => row['transaction_id'] as int)
            .toSet();
        if (attachedTransactionIds.length == 1) {
          await attachTo(attachedTransactionIds.single);
          return SmsTransferSaveOutcome.attached;
        }

        if (linkedAccountId != null && linkedAccountId != mappedAccountId) {
          sourceAccountId = direction == TransferObservationDirection.outgoing
              ? mappedAccountId
              : linkedAccountId;
          destinationAccountId =
              direction == TransferObservationDirection.outgoing
              ? linkedAccountId
              : mappedAccountId;
          final existing = await txn.query(
            'transactions',
            where: 'type=? AND status=? AND amount=? AND account_id=? AND destination_account_id=?',
            whereArgs: [
              TransactionType.transfer.name,
              ReviewStatus.confirmed.name,
              candidate.amountMinor,
              sourceAccountId,
              destinationAccountId,
            ],
          );
          final compatible = <Map<String, Object?>>[];
          for (final row in existing) {
            final observations = await txn.query(
              'sms_transfer_observations',
              where: 'transaction_id=?',
              whereArgs: [row['id']],
            );
            final timeMatches = observations.any(
              (item) => closeEnough(item['sms_received_at'] as String),
            );
            final hintMatches = observations.every(
              (item) => compatibleHint(item['account_hint_hash']),
            );
            if (timeMatches && hintMatches) compatible.add(row);
          }
          if (compatible.length == 1) {
            await attachTo(compatible.single['id'] as int);
            return SmsTransferSaveOutcome.attached;
          }
        }

        final pendingRows = await txn.query(
          'sms_transfer_observations',
          where: 'status=? AND direction=? AND amount=? AND currency=? AND mapped_account_id<>?',
          whereArgs: [
            SmsTransferObservationStatus.pending.name,
            opposite.name,
            candidate.amountMinor,
            candidate.currency.toUpperCase(),
            mappedAccountId,
          ],
        );
        final compatiblePending = pendingRows.where((row) {
          if (!closeEnough(row['sms_received_at'] as String) ||
              !compatibleHint(row['account_hint_hash'])) {
            return false;
          }
          final otherMapped = row['mapped_account_id'] as int;
          final otherLinked = row['linked_account_id'] as int?;
          final relationshipsAgree =
              (linkedAccountId == null || linkedAccountId == otherMapped) &&
              (otherLinked == null || otherLinked == mappedAccountId);
          final sharedHint =
              candidate.accountHintHash != null &&
              row['account_hint_hash'] == candidate.accountHintHash;
          final configuredRelationship =
              linkedAccountId == otherMapped || otherLinked == mappedAccountId;
          return relationshipsAgree && (sharedHint || configuredRelationship);
        }).toList();

        if (compatiblePending.length == 1) {
          final other = compatiblePending.single;
          sourceAccountId = direction == TransferObservationDirection.outgoing
              ? mappedAccountId
              : other['mapped_account_id'] as int;
          destinationAccountId =
              direction == TransferObservationDirection.outgoing
              ? other['mapped_account_id'] as int
              : mappedAccountId;
          final transactionId = await _insertCanonicalSmsTransfer(
            txn,
            amountMinor: candidate.amountMinor,
            sourceAccountId: sourceAccountId,
            destinationAccountId: destinationAccountId,
            date: direction == TransferObservationDirection.outgoing
                ? candidate.transactionDate
                : DateTime.parse(other['sms_received_at'] as String),
            source:
                source == TransactionSource.smsLive ||
                    other['source'] == TransactionSource.smsLive.name
                ? TransactionSource.smsLive
                : TransactionSource.smsImport,
            providerTransactionAt:
                direction == TransferObservationDirection.outgoing
                ? candidate.providerTransactionAt
                : DateTime.tryParse(
                    other['provider_transaction_at'] as String? ?? '',
                  ),
            smsReceivedAt: smsReceivedAt,
          );
          await txn.update(
            'sms_transfer_observations',
            {'transaction_id': transactionId, 'status': 'attached'},
            where: 'id=?',
            whereArgs: [other['id']],
          );
          await txn.insert('transaction_fingerprints', {
            'fingerprint': other['fingerprint'],
            'transaction_id': transactionId,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await attachTo(transactionId);
          return SmsTransferSaveOutcome.created;
        }

        if (sourceAccountId != null && destinationAccountId != null) {
          final transactionId = await _insertCanonicalSmsTransfer(
            txn,
            amountMinor: candidate.amountMinor,
            sourceAccountId: sourceAccountId,
            destinationAccountId: destinationAccountId,
            date: candidate.transactionDate,
            source: source,
            providerTransactionAt: candidate.providerTransactionAt,
            smsReceivedAt: smsReceivedAt,
          );
          await attachTo(transactionId);
          return SmsTransferSaveOutcome.created;
        }

        await txn.insert('sms_transfer_observations', observationValues());
        return SmsTransferSaveOutcome.pending;
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return SmsTransferSaveOutcome.duplicate;
      }
      rethrow;
    }
  }

  Future<int> _insertCanonicalSmsTransfer(
    DatabaseExecutor txn, {
    required int amountMinor,
    required int sourceAccountId,
    required int destinationAccountId,
    required DateTime date,
    required TransactionSource source,
    required DateTime? providerTransactionAt,
    required DateTime smsReceivedAt,
  }) async {
    if (sourceAccountId == destinationAccountId) {
      throw ArgumentError('A transfer requires different owned accounts.');
    }
    final currencies = await txn.query(
      'accounts',
      columns: ['id', 'currency'],
      where: 'id IN (?, ?)',
      whereArgs: [sourceAccountId, destinationAccountId],
    );
    if (currencies.length != 2 ||
        currencies[0]['currency'] != currencies[1]['currency']) {
      throw ArgumentError(
        'Transfers must use accounts with the same currency.',
      );
    }
    return txn.insert('transactions', {
      'amount': amountMinor,
      'type': TransactionType.transfer.name,
      'title': 'Transfer',
      'category': 'Transfer',
      'account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'transaction_date': date.toIso8601String(),
      'source': source.name,
      'status': ReviewStatus.confirmed.name,
      'notes': '',
      'provider_transaction_at': providerTransactionAt
          ?.toUtc()
          .toIso8601String(),
      'sms_received_at': smsReceivedAt.toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

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
        throw ArgumentError(
          'Transfers must use accounts with the same currency.',
        );
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
      await txn.update(
        'transfer_candidates',
        {
          'status': TransferCandidateStatus.linked.name,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: '(outgoing_transaction_id=? AND incoming_transaction_id=?) OR (outgoing_transaction_id=? OR incoming_transaction_id=? OR outgoing_transaction_id=? OR incoming_transaction_id=?)',
        whereArgs: [
          outgoingTransactionId,
          incomingTransactionId,
          outgoingTransactionId,
          outgoingTransactionId,
          incomingTransactionId,
          incomingTransactionId,
        ],
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
          0 ||
      (Sqflite.firstIntValue(
                await (await db).rawQuery(
                  'SELECT COUNT(*) FROM sms_transfer_observations WHERE transaction_id=? AND status=?',
                  [transactionId, SmsTransferObservationStatus.attached.name],
                ),
              ) ??
              0) >
          0;

  Future<List<SmsTransferObservation>> pendingSmsTransferObservations() async =>
      (await db)
          .rawQuery(
            '''
              SELECT o.*, p.name AS provider_name
              FROM sms_transfer_observations o
              JOIN sms_providers p ON p.id=o.provider_id
              WHERE o.status=?
              ORDER BY o.sms_received_at DESC
            ''',
            [SmsTransferObservationStatus.pending.name],
          )
          .then(
            (rows) => rows
                .map(
                  (row) => SmsTransferObservation(
                    id: row['id'] as int,
                    transactionId: row['transaction_id'] as int?,
                    providerId: row['provider_id'] as int,
                    providerName: row['provider_name'] as String,
                    mappedAccountId: row['mapped_account_id'] as int,
                    linkedAccountId: row['linked_account_id'] as int?,
                    direction: TransferObservationDirection.values.byName(
                      row['direction'] as String,
                    ),
                    amountMinor: row['amount'] as int,
                    currency: row['currency'] as String,
                    providerTransactionAt: DateTime.tryParse(
                      row['provider_transaction_at'] as String? ?? '',
                    ),
                    smsReceivedAt: DateTime.parse(
                      row['sms_received_at'] as String,
                    ),
                    source: TransactionSource.values.byName(
                      row['source'] as String,
                    ),
                    status: SmsTransferObservationStatus.values.byName(
                      row['status'] as String,
                    ),
                  ),
                )
                .toList(),
          );

  Future<void> resolvePendingSmsTransfer(
    int observationId,
    int counterpartAccountId,
  ) async {
    final database = await db;
    await database.transaction((txn) async {
      final row = (await txn.query(
        'sms_transfer_observations',
        where: 'id=? AND status=?',
        whereArgs: [observationId, SmsTransferObservationStatus.pending.name],
      )).firstOrNull;
      if (row == null) throw StateError('Transfer observation not found.');
      final mapped = row['mapped_account_id'] as int;
      if (mapped == counterpartAccountId) {
        throw ArgumentError('Choose a different owned account.');
      }
      await txn.update(
        'provider_account_mappings',
        {'linked_account_id': counterpartAccountId},
        where: 'provider_id=? AND account_id=?',
        whereArgs: [row['provider_id'], mapped],
      );
      final direction = TransferObservationDirection.values.byName(
        row['direction'] as String,
      );
      final sourceId = direction == TransferObservationDirection.outgoing
          ? mapped
          : counterpartAccountId;
      final destinationId = direction == TransferObservationDirection.outgoing
          ? counterpartAccountId
          : mapped;
      final transactionId = await _insertCanonicalSmsTransfer(
        txn,
        amountMinor: row['amount'] as int,
        sourceAccountId: sourceId,
        destinationAccountId: destinationId,
        date:
            DateTime.tryParse(
              row['provider_transaction_at'] as String? ?? '',
            ) ??
            DateTime.parse(row['sms_received_at'] as String),
        source: TransactionSource.values.byName(row['source'] as String),
        providerTransactionAt: DateTime.tryParse(
          row['provider_transaction_at'] as String? ?? '',
        ),
        smsReceivedAt: DateTime.parse(row['sms_received_at'] as String),
      );
      await txn.update(
        'sms_transfer_observations',
        {
          'transaction_id': transactionId,
          'linked_account_id': counterpartAccountId,
          'status': SmsTransferObservationStatus.attached.name,
        },
        where: 'id=?',
        whereArgs: [observationId],
      );
      await txn.insert('transaction_fingerprints', {
        'fingerprint': row['fingerprint'],
        'transaction_id': transactionId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final opposite = direction == TransferObservationDirection.outgoing
          ? TransferObservationDirection.incoming
          : TransferObservationDirection.outgoing;
      final counterparts = await txn.query(
        'sms_transfer_observations',
        where: 'status=? AND direction=? AND mapped_account_id=? AND amount=? AND currency=? AND id<>?',
        whereArgs: [
          SmsTransferObservationStatus.pending.name,
          opposite.name,
          counterpartAccountId,
          row['amount'],
          row['currency'],
          observationId,
        ],
      );
      final compatible = counterparts.where((other) {
        final hint = row['account_hint_hash'];
        final otherHint = other['account_hint_hash'];
        final hintsAgree =
            hint == null || otherHint == null || hint == otherHint;
        final timeDistance = DateTime.parse(row['sms_received_at'] as String)
            .difference(DateTime.parse(other['sms_received_at'] as String))
            .abs();
        return hintsAgree && timeDistance <= const Duration(hours: 2);
      }).toList();
      if (compatible.length == 1) {
        final other = compatible.single;
        await txn.update(
          'sms_transfer_observations',
          {
            'transaction_id': transactionId,
            'linked_account_id': mapped,
            'status': SmsTransferObservationStatus.attached.name,
          },
          where: 'id=?',
          whereArgs: [other['id']],
        );
        await txn.insert('transaction_fingerprints', {
          'fingerprint': other['fingerprint'],
          'transaction_id': transactionId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> rejectPendingSmsTransfer(int observationId) async =>
      (await db).update(
        'sms_transfer_observations',
        {'status': SmsTransferObservationStatus.rejected.name},
        where: 'id=? AND status=?',
        whereArgs: [observationId, SmsTransferObservationStatus.pending.name],
      );

  Future<List<TransferCandidate>> transferCandidates() async {
    final database = await db;
    final rows = await database.query(
      'transfer_candidates',
      where: 'status=?',
      whereArgs: [TransferCandidateStatus.possible.name],
      orderBy: 'created_at DESC',
    );
    final all = {for (final item in await transactions()) item.id!: item};
    return rows
        .map((row) {
          final outgoing = all[row['outgoing_transaction_id'] as int];
          final incoming = all[row['incoming_transaction_id'] as int];
          if (outgoing == null || incoming == null) return null;
          return TransferCandidate(
            id: row['id'] as int,
            outgoing: outgoing,
            incoming: incoming,
            confidence: row['confidence'] as String,
            status: TransferCandidateStatus.values.byName(
              row['status'] as String,
            ),
            createdAt: DateTime.parse(row['created_at'] as String),
            resolvedAt: DateTime.tryParse(row['resolved_at'] as String? ?? ''),
          );
        })
        .whereType<TransferCandidate>()
        .toList();
  }

  Future<void> rejectTransferCandidate(int candidateId) async {
    await (await db).update(
      'transfer_candidates',
      {
        'status': TransferCandidateStatus.rejected.name,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=? AND status=?',
      whereArgs: [candidateId, TransferCandidateStatus.possible.name],
    );
  }

  Future<void> unlinkTransfer(int outgoingTransactionId) async {
    final database = await db;
    await database.transaction((txn) async {
      final link = (await txn.query(
        'transfer_reconciliations',
        where: 'outgoing_transaction_id=?',
        whereArgs: [outgoingTransactionId],
      )).firstOrNull;
      if (link == null) {
        final observations = await txn.query(
          'sms_transfer_observations',
          where: 'transaction_id=? AND status=?',
          whereArgs: [
            outgoingTransactionId,
            SmsTransferObservationStatus.attached.name,
          ],
        );
        if (observations.isEmpty) throw StateError('Transfer link not found.');
        for (final observation in observations) {
          await txn.delete(
            'transaction_fingerprints',
            where: 'fingerprint=?',
            whereArgs: [observation['fingerprint']],
          );
        }
        await txn.update(
          'sms_transfer_observations',
          {
            'transaction_id': null,
            'status': SmsTransferObservationStatus.pending.name,
          },
          where: 'transaction_id=?',
          whereArgs: [outgoingTransactionId],
        );
        await txn.delete(
          'transactions',
          where: 'id=?',
          whereArgs: [outgoingTransactionId],
        );
        return;
      }
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
      await txn.update(
        'transfer_candidates',
        {'status': TransferCandidateStatus.possible.name, 'resolved_at': null},
        where: 'outgoing_transaction_id=? OR incoming_transaction_id=?',
        whereArgs: [outgoingTransactionId, outgoingTransactionId],
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
    late final int budgetId;
    if (b.id == null) {
      budgetId = await database.insert('budgets', values);
    } else {
      budgetId = b.id!;
      await database.update(
        'budgets',
        values,
        where: 'id=?',
        whereArgs: [b.id],
      );
    }
    await recordCurrentBudgetLimit(
      Budget(
        id: budgetId,
        name: b.name,
        category: b.category,
        amountMinor: b.amountMinor,
        period: b.period,
        startDate: b.startDate,
        alertThreshold: b.alertThreshold,
        archived: b.archived,
      ),
      overwrite: true,
    );
  }

  Future<void> recordCurrentBudgetLimit(
    Budget budget, {
    bool overwrite = false,
    DateTime? asOf,
  }) async {
    if (budget.id == null) return;
    final bounds = BudgetPeriodCalculator.current(budget, asOf: asOf);
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'budget_id': budget.id,
      'period_start': bounds.start.toIso8601String(),
      'period_end': bounds.end.toIso8601String(),
      'amount': budget.amountMinor,
      'category': budget.category,
      'period': budget.period,
      'recorded_at': now,
      'updated_at': now,
    };
    final database = await db;
    if (overwrite) {
      final changed = await database.update(
        'budget_period_limits',
        {
          'amount': budget.amountMinor,
          'category': budget.category,
          'period': budget.period,
          'period_end': bounds.end.toIso8601String(),
          'updated_at': now,
        },
        where: 'budget_id=? AND period_start=? AND period_end=? AND period=?',
        whereArgs: [
          budget.id,
          bounds.start.toIso8601String(),
          bounds.end.toIso8601String(),
          budget.period,
        ],
      );
      if (changed > 0) return;
    }
    await database.insert(
      'budget_period_limits',
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> recordCurrentBudgetLimits({DateTime? asOf}) async {
    for (final budget in await budgets()) {
      await recordCurrentBudgetLimit(budget, asOf: asOf);
    }
  }

  Future<List<BudgetLimitSnapshot>> budgetLimitSnapshots(int budgetId) async =>
      (await db)
          .query(
            'budget_period_limits',
            where: 'budget_id=?',
            whereArgs: [budgetId],
            orderBy: 'period_start DESC',
          )
          .then(
            (rows) => rows
                .map(
                  (row) => BudgetLimitSnapshot(
                    budgetId: row['budget_id'] as int,
                    start: DateTime.parse(row['period_start'] as String),
                    end: DateTime.parse(row['period_end'] as String),
                    amountMinor: row['amount'] as int,
                    category: row['category'] as String,
                    period: row['period'] as String,
                  ),
                )
                .toList(),
          );

  Future<List<Transaction>> budgetHistoryTransactions({
    String? category,
    required DateTime start,
    required DateTime end,
  }) async {
    final categoryClause = category == null ? '' : 'category=? AND ';
    return (await db)
        .query(
          'transactions',
          where:
              '${categoryClause}type=? AND status=? '
              'AND transaction_date>=? AND transaction_date<?',
          whereArgs: [
            ?category,
            TransactionType.expense.name,
            ReviewStatus.confirmed.name,
            start.toIso8601String(),
            end.add(const Duration(days: 1)).toIso8601String(),
          ],
          orderBy: 'transaction_date DESC',
        )
        .then((rows) => rows.map(_transaction).toList());
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
      await database.transaction((transaction) async {
        final existing = await transaction.query(
          'categories',
          columns: ['name'],
          where: 'id=?',
          whereArgs: [category.id],
          limit: 1,
        );
        final previousName = existing.firstOrNull?['name'] as String?;

        await transaction.update(
          'categories',
          values,
          where: 'id=?',
          whereArgs: [category.id],
        );

        final nextName = category.name.trim();
        if (previousName != null && previousName != nextName) {
          for (final table in [
            'transactions',
            'budgets',
            'recurring_transactions',
            'merchant_rules',
          ]) {
            await transaction.update(
              table,
              {'category': nextName},
              where: 'category=?',
              whereArgs: [previousName],
            );
          }
        }
      });
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

  Future<void> setRecurringTransactionEnabled(int id, bool enabled) async =>
      (await db).update(
        'recurring_transactions',
        {'is_enabled': enabled ? 1 : 0},
        where: 'id=? AND is_archived=0',
        whereArgs: [id],
      );

  Future<List<Transaction>> recurringTransactionHistory(int recurringId) async {
    final rows = await (await db).rawQuery(
      'SELECT t.* FROM transactions t '
      'INNER JOIN recurring_occurrences occurrence '
      'ON occurrence.transaction_id=t.id '
      'WHERE occurrence.recurring_id=? '
      'ORDER BY t.transaction_date DESC, t.id DESC',
      [recurringId],
    );
    return rows.map(_transaction).toList(growable: false);
  }

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
      if (count > 0) {
        await txn.update(
          'recurring_transactions',
          {'next_occurrence': next.toIso8601String()},
          where: 'id=?',
          whereArgs: [item.id],
        );
        return false;
      }
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
      final database = await db;
      final existing = await database.query(
        'sms_providers',
        columns: const ['id'],
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [provider.name.trim()],
        limit: 1,
      );
      if (existing.isEmpty) {
        await database.insert('sms_providers', values);
      } else {
        await database.update(
          'sms_providers',
          values,
          where: 'id=?',
          whereArgs: [existing.single['id']],
        );
      }
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
                    linkedAccountId: row['linked_account_id'] as int?,
                  ),
                )
                .toList(),
          );

  Future<void> setProviderAccountMapping(
    int providerId,
    int accountId, {
    int? linkedAccountId,
  }) async {
    final database = await db;
    await database.insert('provider_account_mappings', {
      'provider_id': providerId,
      'account_id': accountId,
      'linked_account_id': linkedAccountId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (linkedAccountId != null) {
      await database.update(
        'provider_account_mappings',
        {'linked_account_id': linkedAccountId},
        where: 'provider_id=? AND account_id=?',
        whereArgs: [providerId, accountId],
      );
    }
  }

  Future<void> setProviderLinkedAccount(int mappingId, int? accountId) async =>
      (await db).update(
        'provider_account_mappings',
        {'linked_account_id': accountId},
        where: 'id=?',
        whereArgs: [mappingId],
      );

  Future<void> removeProviderAccountMapping(int id) async => (await db).delete(
    'provider_account_mappings',
    where: 'id=?',
    whereArgs: [id],
  );
}
