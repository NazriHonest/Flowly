import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/accounts/domain/entities/account.dart';
import 'package:flowly/features/sms_detection/domain/entities/sms_provider.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late AppDatabase db;
  final at = DateTime.utc(2026, 10, 1, 10);
  Future<void> setup() async {
    dir = await Directory.systemTemp.createTemp('flowly-transfer-');
    db = AppDatabase.forTesting(
      '${dir.path}${Platform.pathSeparator}flowly.db',
    );
    await db.db;
    await db.saveAccount(
      const Account(name: 'A', openingBalanceMinor: 10000, currency: 'USD'),
    );
    await db.saveAccount(
      const Account(name: 'B', openingBalanceMinor: 5000, currency: 'USD'),
    );
    await db.saveSmsProvider(
      const SmsProvider(name: 'JEEB', senderAliases: [], enabled: true),
    );
    await db.saveSmsProvider(
      const SmsProvider(name: 'EVC', senderAliases: [], enabled: true),
    );
    final a = await db.accounts();
    final p = await db.smsProviders();
    await db.setProviderAccountMapping(p[0].id!, a[0].id!);
    await db.setProviderAccountMapping(p[1].id!, a[1].id!);
  }

  Transaction tx(
    TransactionType type,
    int account,
    DateTime receipt, {
    int amount = 5000,
    String category = 'Other',
  }) => Transaction(
    amountMinor: amount,
    type: type,
    title: type == TransactionType.expense ? 'JEEB' : 'EVC',
    category: category,
    accountId: account,
    date: at,
    source: TransactionSource.smsLive,
    status: ReviewStatus.confirmed,
    providerTransactionAt: at,
    smsReceivedAt: receipt,
  );
  setUp(setup);
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  test('strong pair links, preserves snapshots, balances and unlink restores metadata', () async {
    final a = await db.accounts();
    await db.saveDetectedTransaction(
      tx(TransactionType.expense, a[0].id!, at),
      'o',
    );
    final original = (await db.transactions()).single;
    await db.saveDetectedTransaction(
      tx(TransactionType.income, a[1].id!, at.add(const Duration(minutes: 1))),
      'i',
    );
    final all = await db.transactions();
    final out = all.firstWhere((x) => x.type == TransactionType.transfer);
    final incoming = all.firstWhere((x) => x.id != out.id);
    expect(out.destinationAccountId, a[1].id);
    expect(incoming.status, ReviewStatus.ignored);
    final c = await (await db.db).query('transfer_candidates');
    expect(c, hasLength(1));
    expect(c.single['status'], 'linked');
    expect(
      (await (await db.db).query('transfer_reconciliations'))
          .single['outgoing_snapshot'],
      isNotEmpty,
    );
    final source = 10000 - out.amountMinor;
    final destination = 5000 + out.amountMinor;
    expect(source, 5000);
    expect(destination, 10000);
    expect(source + destination, 15000);
    await db.unlinkTransfer(out.id!);
    final restored = (await db.transactions()).firstWhere(
      (x) => x.id == out.id,
    );
    expect(restored.type, TransactionType.expense);
    expect(restored.providerTransactionAt, original.providerTransactionAt);
    expect(restored.smsReceivedAt, original.smsReceivedAt);
    expect(restored.createdAt, original.createdAt);
  });
  test('possible candidate persists, rejects idempotently, and has no raw SMS columns', () async {
    final a = await db.accounts();
    await db.saveDetectedTransaction(
      tx(TransactionType.expense, a[0].id!, at),
      'o',
    );
    await db.saveDetectedTransaction(
      tx(TransactionType.income, a[1].id!, at.add(const Duration(minutes: 30))),
      'i',
    );
    final possible = await db.transferCandidates();
    expect(possible, hasLength(1));
    final id = possible.single.id;
    await db.rejectTransferCandidate(id);
    await db.reconcileDetectedTransaction(2);
    final rows = await (await db.db).query('transfer_candidates');
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'rejected');
    expect(rows.single['resolved_at'], isNotNull);
    final names = (await (await db.db).rawQuery(
      'PRAGMA table_info(transfer_candidates)',
    )).map((r) => r['name']).toSet();
    expect(
      names.intersection({
        'sms_body',
        'raw_sms',
        'message',
        'raw_message',
        'intent',
        'intent_data',
        'payload',
        'raw_payload',
      }),
      isEmpty,
    );
    await db.close();
    db = AppDatabase.forTesting(
      '${dir.path}${Platform.pathSeparator}flowly.db',
    );
    expect(
      (await (await db.db).query('transfer_candidates')).single['status'],
      'rejected',
    );
  });
}
