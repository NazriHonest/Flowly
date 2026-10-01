import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';
import 'package:flowly/features/transactions/domain/services/transfer_reconciliation_service.dart';

Transaction transaction({
  required int id,
  required TransactionType type,
  required int accountId,
  int amount = 5000,
  DateTime? providerAt,
  DateTime? receivedAt,
}) => Transaction(
  id: id,
  amountMinor: amount,
  type: type,
  title: type == TransactionType.expense ? 'JEEB' : 'EVC Plus',
  category: 'Transfer',
  accountId: accountId,
  date: providerAt ?? DateTime(2026, 10, 1, 10),
  source: TransactionSource.smsLive,
  providerTransactionAt: providerAt,
  smsReceivedAt: receivedAt,
);

void main() {
  final service = TransferReconciliationService();
  const currencyFor = _currencyFor;
  final at = DateTime(2026, 10, 1, 10);
  final outgoing = transaction(
    id: 1,
    type: TransactionType.expense,
    accountId: 10,
    providerAt: at,
    receivedAt: at,
  );

  test('strong match needs independent receipt and provider-time evidence', () {
    final incoming = transaction(
      id: 2,
      type: TransactionType.income,
      accountId: 11,
      providerAt: at.add(const Duration(minutes: 3)),
      receivedAt: at.add(const Duration(minutes: 2)),
    );
    expect(
      service.strongestFor(
        outgoing: outgoing,
        transactions: [incoming],
        outgoingCurrency: 'KES',
        currencyForAccount: currencyFor,
      )?.incoming.id,
      2,
    );
  });

  test('legacy records without receipt time are possible, never automatic', () {
    final incoming = transaction(
      id: 2,
      type: TransactionType.income,
      accountId: 11,
      providerAt: at.add(const Duration(minutes: 2)),
    );
    expect(
      service.strongestFor(
        outgoing: outgoing,
        transactions: [incoming],
        outgoingCurrency: 'KES',
        currencyForAccount: currencyFor,
      ),
      isNull,
    );
    expect(
      service.candidatesFor(
        outgoing: outgoing,
        transactions: [incoming],
        outgoingCurrency: 'KES',
        currencyForAccount: currencyFor,
      ).single.confidence,
      TransferMatchConfidence.possible,
    );
  });

  test('same amount alone cannot match another currency, account, or late row', () {
    final wrongCurrency = transaction(
      id: 2,
      type: TransactionType.income,
      accountId: 12,
      receivedAt: at,
    );
    final sameAccount = transaction(
      id: 3,
      type: TransactionType.income,
      accountId: 10,
      receivedAt: at,
    );
    final late = transaction(
      id: 4,
      type: TransactionType.income,
      accountId: 11,
      receivedAt: at.add(const Duration(hours: 3)),
    );
    expect(
      service.candidatesFor(
        outgoing: outgoing,
        transactions: [wrongCurrency, sameAccount, late],
        outgoingCurrency: 'KES',
        currencyForAccount: currencyFor,
      ),
      isEmpty,
    );
  });

  test('multiple strong candidates remain ambiguous', () {
    final a = transaction(
      id: 2,
      type: TransactionType.income,
      accountId: 11,
      providerAt: at,
      receivedAt: at,
    );
    final b = transaction(
      id: 3,
      type: TransactionType.income,
      accountId: 13,
      providerAt: at,
      receivedAt: at,
    );
    expect(
      service.strongestFor(
        outgoing: outgoing,
        transactions: [a, b],
        outgoingCurrency: 'KES',
        currencyForAccount: currencyFor,
      ),
      isNull,
    );
  });
}

String _currencyFor(int accountId) => accountId == 12 ? 'USD' : 'KES';
