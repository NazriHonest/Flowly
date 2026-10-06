import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/accounts/domain/entities/account.dart';
import 'package:flowly/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:flowly/features/sms_detection/domain/entities/sms_provider.dart';
import 'package:flowly/features/sms_detection/domain/entities/sms_transfer_observation.dart';
import 'package:flowly/features/sms_detection/domain/entities/transaction_candidate.dart';
import 'package:flowly/features/sms_detection/parsers/provider_sms_parser.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory directory;
  late AppDatabase database;
  late Account jeeb;
  late Account agro;
  late SmsProvider jeebProvider;
  late SmsProvider agroProvider;
  late Future<void> Function() mapLinked;
  late Future<SmsTransferSaveOutcome> Function({
    required SmsProvider provider,
    required Account mapped,
    Account? linked,
    required TransferObservationDirection direction,
    required String fingerprint,
    DateTime? receivedAt,
  })
  saveObservation;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flowly-bank-transfer-');
    database = AppDatabase.forTesting(
      '${directory.path}${Platform.pathSeparator}flowly.db',
    );
    await database.db;
    await database.saveAccount(
      const Account(
        name: 'JEEB',
        openingBalanceMinor: 5000,
        type: 'mobile_money',
        currency: 'USD',
      ),
    );
    await database.saveAccount(
      const Account(
        name: 'Agro Bank',
        openingBalanceMinor: 10000,
        type: 'bank',
        currency: 'USD',
      ),
    );
    final accounts = await database.accounts();
    jeeb = accounts.firstWhere((account) => account.name == 'JEEB');
    agro = accounts.firstWhere((account) => account.name == 'Agro Bank');
    final providers = await database.smsProviders();
    jeebProvider = providers.firstWhere((provider) => provider.name == 'JEEB');
    agroProvider = providers.firstWhere(
      (provider) => provider.name == 'AGROBANK',
    );
    mapLinked = () async {
      await database.setProviderAccountMapping(
        jeebProvider.id!,
        jeeb.id!,
        linkedAccountId: agro.id,
      );
      await database.setProviderAccountMapping(
        agroProvider.id!,
        agro.id!,
        linkedAccountId: jeeb.id,
      );
    };
    saveObservation =
        ({
          required SmsProvider provider,
          required Account mapped,
          Account? linked,
          required TransferObservationDirection direction,
          required String fingerprint,
          DateTime? receivedAt,
        }) => database.saveInternalTransferObservation(
          candidate: TransactionCandidate(
            type: direction == TransferObservationDirection.outgoing
                ? CandidateType.expense
                : CandidateType.income,
            amountMinor: 1000,
            currency: 'USD',
            provider: provider.name,
            transactionDate: receivedAt ?? DateTime.utc(2026, 10, 6, 11, 13),
            confidence: .95,
            semantics: CandidateSemantics.internalTransfer,
            transferDirection: direction,
            accountHintHash: safeAccountHintHash('201XXX04'),
          ),
          providerId: provider.id!,
          mappedAccountId: mapped.id!,
          linkedAccountId: linked?.id,
          source: TransactionSource.smsLive,
          smsReceivedAt: receivedAt ?? DateTime.utc(2026, 10, 6, 11, 13),
          fingerprint: fingerprint,
        );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'v17 seeds supported providers and adds linked-account storage',
    () async {
      final names = (await database.smsProviders()).map((item) => item.name);
      expect(names, containsAll(['EVC Plus', 'JEEB', 'DEEQTOON', 'AGROBANK']));

      await database.setProviderAccountMapping(
        jeebProvider.id!,
        jeeb.id!,
        linkedAccountId: agro.id,
      );
      final mapping = (await database.providerAccountMappings()).single;
      expect(mapping.linkedAccountId, agro.id);
    },
  );

  test(
    'trusted single-sided observation creates one canonical transfer',
    () async {
      await mapLinked();
      final outcome = await saveObservation(
        provider: jeebProvider,
        mapped: jeeb,
        linked: agro,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'wallet-out',
      );

      expect(outcome, SmsTransferSaveOutcome.created);
      final transfer = (await database.transactions()).single;
      expect(transfer.type, TransactionType.transfer);
      expect(transfer.accountId, jeeb.id);
      expect(transfer.destinationAccountId, agro.id);
      expect(AccountBalanceCalculator.current(jeeb, [transfer]), 4000);
      expect(AccountBalanceCalculator.current(agro, [transfer]), 11000);
      expect(
        AccountBalanceCalculator.current(jeeb, [transfer]) +
            AccountBalanceCalculator.current(agro, [transfer]),
        15000,
      );
    },
  );

  test(
    'late bank-side observation attaches without a second transaction',
    () async {
      await mapLinked();
      await saveObservation(
        provider: jeebProvider,
        mapped: jeeb,
        linked: agro,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'wallet-first',
      );
      final outcome = await saveObservation(
        provider: agroProvider,
        mapped: agro,
        linked: jeeb,
        direction: TransferObservationDirection.incoming,
        fingerprint: 'bank-later',
        receivedAt: DateTime.utc(2026, 10, 6, 11, 14),
      );

      expect(outcome, SmsTransferSaveOutcome.attached);
      expect(await database.transactions(), hasLength(1));
      final observations = await (await database.db).query(
        'sms_transfer_observations',
      );
      expect(observations, hasLength(2));
      expect(
        observations.map((row) => row['transaction_id']).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'two unlinked opposite observations with a shared hint pair once',
    () async {
      await database.setProviderAccountMapping(jeebProvider.id!, jeeb.id!);
      await database.setProviderAccountMapping(agroProvider.id!, agro.id!);
      final first = await saveObservation(
        provider: agroProvider,
        mapped: agro,
        direction: TransferObservationDirection.incoming,
        fingerprint: 'bank-first',
      );
      final second = await saveObservation(
        provider: jeebProvider,
        mapped: jeeb,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'wallet-later',
        receivedAt: DateTime.utc(2026, 10, 6, 11, 15),
      );

      expect(first, SmsTransferSaveOutcome.pending);
      expect(second, SmsTransferSaveOutcome.created);
      final transfer = (await database.transactions()).single;
      expect(transfer.accountId, jeeb.id);
      expect(transfer.destinationAccountId, agro.id);
    },
  );

  test(
    'same direction never links and exact fingerprint deduplicates',
    () async {
      await database.setProviderAccountMapping(jeebProvider.id!, jeeb.id!);
      await database.setProviderAccountMapping(agroProvider.id!, agro.id!);
      await saveObservation(
        provider: jeebProvider,
        mapped: jeeb,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'same-direction-a',
      );
      final second = await saveObservation(
        provider: agroProvider,
        mapped: agro,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'same-direction-b',
      );
      final duplicate = await saveObservation(
        provider: agroProvider,
        mapped: agro,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'same-direction-b',
      );

      expect(second, SmsTransferSaveOutcome.pending);
      expect(duplicate, SmsTransferSaveOutcome.duplicate);
      expect(await database.transactions(), isEmpty);
    },
  );

  test(
    'unlink restores observations and manual relink creates one transfer',
    () async {
      await mapLinked();
      await saveObservation(
        provider: jeebProvider,
        mapped: jeeb,
        linked: agro,
        direction: TransferObservationDirection.outgoing,
        fingerprint: 'unlink-wallet',
      );
      await saveObservation(
        provider: agroProvider,
        mapped: agro,
        linked: jeeb,
        direction: TransferObservationDirection.incoming,
        fingerprint: 'unlink-bank',
        receivedAt: DateTime.utc(2026, 10, 6, 11, 14),
      );
      final transactionId = (await database.transactions()).single.id!;

      await database.unlinkTransfer(transactionId);
      final pending = await database.pendingSmsTransferObservations();
      expect(pending, hasLength(2));
      expect(await database.transactions(), isEmpty);

      await database.resolvePendingSmsTransfer(
        pending.first.id,
        jeeb.id == pending.first.mappedAccountId ? agro.id! : jeeb.id!,
      );
      expect(await database.transactions(), hasLength(1));
      expect(await database.pendingSmsTransferObservations(), isEmpty);
    },
  );
}
