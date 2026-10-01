import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/sms_detection/domain/entities/transaction_candidate.dart';
import 'package:flowly/features/sms_detection/domain/services/confidence_calculator.dart';
import 'package:flowly/features/sms_detection/domain/services/duplicate_detector.dart';
import 'package:flowly/features/sms_detection/parsers/generic_financial_parser.dart';
import 'package:flowly/features/sms_detection/parsers/evc_plus_parser.dart';
import 'package:flowly/features/sms_detection/parsers/jeeb_parser.dart';
import 'package:flowly/features/sms_detection/domain/services/financial_sms_parser_registry.dart';
import 'package:flowly/features/sms_detection/domain/services/financial_sms_pipeline.dart';
import 'package:flowly/features/sms_detection/domain/services/financial_message_detector.dart';
import 'package:flowly/core/formatters/money_formatter.dart';
import 'package:flowly/features/sms_detection/data/automatic_transaction_processor.dart';
import 'package:flowly/features/sms_detection/domain/services/sms_timestamp_diagnostics.dart';
import 'package:flowly/features/categorization/domain/services/categorization_service.dart';
import 'package:flowly/features/transactions/domain/entities/transaction.dart';

void main() {
  test('generic parser produces only normalized transaction fields', () {
    final candidate = GenericFinancialParser().parse(
      sender: 'DEVELOPMENT_FIXTURE',
      message: 'Payment of USD 24.50 paid successfully',
      receivedAt: DateTime.utc(2026, 9, 27),
    );
    expect(candidate, isNotNull);
    expect(candidate!.amountMinor, 2450);
    expect(candidate.type, CandidateType.expense);
  });

  test('fingerprint is stable and distinct normalized events differ', () {
    final first = TransactionCandidate(
      type: CandidateType.expense,
      amountMinor: 2450,
      currency: 'USD',
      provider: 'Fixture',
      reference: 'abc',
      transactionDate: DateTime.utc(2026, 9, 27),
      confidence: .9,
    );
    final detector = DuplicateDetector();
    expect(detector.fingerprint(first), detector.fingerprint(first));
    expect(
      detector.fingerprint(first),
      isNot(
        detector.fingerprint(
          TransactionCandidate(
            type: CandidateType.expense,
            amountMinor: 2500,
            currency: 'USD',
            provider: 'Fixture',
            reference: 'abc',
            transactionDate: DateTime.utc(2026, 9, 27),
            confidence: .9,
          ),
        ),
      ),
    );
  });

  test('a live SMS transaction is always marked smsLive', () {
    final transaction = createLiveSmsTransaction(
      candidate: TransactionCandidate(
        type: CandidateType.income,
        amountMinor: 15000,
        currency: 'USD',
        provider: 'Fixture',
        transactionDate: DateTime.utc(2026, 9, 30),
        confidence: .9,
      ),
      merchant: 'Fixture',
      category: 'Other',
      accountId: 1,
      status: ReviewStatus.confirmed,
      smsReceivedAt: DateTime.utc(2026, 9, 30, 12),
    );

    expect(transaction.source, TransactionSource.smsLive);
    expect(transaction.source, isNot(TransactionSource.smsImport));
  });

  test('provider and SMS receipt times remain distinct without correction', () {
    final providerTime = DateTime(2026, 9, 30, 9, 0);
    final receiptTime = DateTime(2026, 9, 30, 16, 30);
    final transaction = Transaction(
      amountMinor: 100,
      type: TransactionType.income,
      title: 'Fixture',
      category: 'Other',
      accountId: 1,
      date: providerTime,
      providerTransactionAt: providerTime,
      smsReceivedAt: receiptTime,
      createdAt: DateTime.utc(2026, 9, 30, 16, 31),
    );
    const diagnostics = SmsTimestampDiagnostics();

    expect(transaction.date, providerTime);
    expect(transaction.providerTransactionAt, providerTime);
    expect(transaction.smsReceivedAt, receiptTime);
    expect(transaction.createdAt, isNot(transaction.smsReceivedAt));
    expect(
      diagnostics.hasUnexpectedDifference(
        providerTransactionAt: transaction.providerTransactionAt,
        smsReceivedAt: transaction.smsReceivedAt,
      ),
      isTrue,
    );
  });

  test('malformed provider timestamp falls back to SMS receipt time', () {
    final received = DateTime.utc(2026, 9, 30, 12);
    final candidate = EvcPlusParser().parse(
      sender: 'fixture',
      message: '[-EVCPLUS-] \$1 ayaad uwareejisay TEST, Tar: 31/02/2026 10:00:00',
      receivedAt: received,
    );

    expect(candidate?.transactionDate, received);
    expect(candidate?.providerTransactionAt, isNull);
  });

  test('normalized counterparty uses explicit learned rules before Other', () {
    const categorization = CategorizationService();
    final category = categorization.suggest(
      merchant: '  Fixture   Counterparty ',
      merchantRules: const [MerchantRule('fixture counterparty', 'Food & Dining')],
      keywordRules: const [],
    );
    final unknown = categorization.suggest(
      merchant: 'Unknown Person',
      merchantRules: const [],
      keywordRules: const [],
    );

    expect(category, 'Food & Dining');
    expect(unknown, 'Other');
  });

  test('confidence thresholds protect confirmed balances', () {
    const engine = ConfidenceCalculator();
    expect(engine.disposition(.95), DetectionDisposition.confirmed);
    expect(engine.disposition(.75), DetectionDisposition.needsReview);
    expect(engine.disposition(.50), DetectionDisposition.rejected);
  });

  test('EVC Plus outgoing fixture is parsed without raw SMS fields', () {
    final candidate = EvcPlusParser().parse(
      sender: '+000000000',
      message:
          '[-EVCPLUS-] \$58 ayaad uwareejisay TEST USER (600000000), Tar: 29/09/26 07:36:56, Haraagaagu waa \$0.5.',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    expect(candidate?.provider, 'EVC Plus');
    expect(candidate?.type, CandidateType.expense);
    expect(candidate?.amountMinor, 5800);
    expect(candidate?.currency, 'USD');
    expect(candidate?.merchant, 'TEST USER');
    expect(candidate?.transactionDate, DateTime(2026, 9, 29, 7, 36, 56));
    expect(candidate?.confidence, .92);
  });

  test('EVC Plus incoming fixture is parsed', () {
    final candidate = EvcPlusParser().parse(
      sender: 'fixture',
      message:
          '[-EVCPLUS-] waxaad \$150 ka heshay 0600000000, Tar: 27/09/26 13:09:20 haraagagu waa \$165.',
      receivedAt: DateTime.utc(2026, 9, 27),
    );
    expect(candidate?.type, CandidateType.income);
    expect(candidate?.amountMinor, 15000);
    expect(candidate?.transactionDate, DateTime(2026, 9, 27, 13, 9, 20));
  });

  test('JEEB fixtures support milliseconds and integer/decimal amounts', () {
    final outgoing = JeebParser().parse(
      sender: 'fixture',
      message:
          '[-JEEB-] \$0.5 ayaad u dirtay TEST PERSON(610000000),Tar: 29/09/2026 20:41:55:142 haraagaagu waa \$2.98.',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    final incoming = JeebParser().parse(
      sender: 'fixture',
      message:
          '[-JEEB-] \$3 ayaad ka Heshay 252600000000,29/09/2026 21:21:16 via Local Clearing House, Haraagaagu waa \$3.48.',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    expect(outgoing?.type, CandidateType.expense);
    expect(outgoing?.amountMinor, 50);
    expect(outgoing?.merchant, 'TEST PERSON');
    expect(outgoing?.transactionDate, DateTime(2026, 9, 29, 20, 41, 55));
    expect(incoming?.type, CandidateType.income);
    expect(incoming?.amountMinor, 300);
    expect(incoming?.merchant, isNull);
  });

  test('provider parsers precede generic fallback and reject ordinary Somali SMS', () {
    final registry = FinancialSmsParserRegistry([
      EvcPlusParser(),
      JeebParser(),
      GenericFinancialParser(),
    ]);
    final provider = registry.parse(
      sender: 'fixture',
      message: '[-JEEB-] \$1 ayaad u dirtay TEST(600000000),Tar: 29/09/26 10:00:00',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    final ordinary = registry.parse(
      sender: 'fixture',
      message: 'Kulanka wuxuu bilaabanayaa 29/09/26 saacadu markay tahay 10:00.',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    expect(provider?.provider, 'JEEB');
    expect(ordinary, isNull);
  });

  test('EVC Plus marker passes the full detector and pipeline', () {
    final pipeline = FinancialSmsPipeline(
      FinancialSmsParserRegistry([
        EvcPlusParser(),
        JeebParser(),
        GenericFinancialParser(),
      ]),
    );
    final result = pipeline.process(
      sender: 'fixture',
      message:
          '[-EVCPLUS-] \$58 ayaad uwareejisay TEST USER (600000000), Tar: 29/09/26 07:36:56',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    expect(const FinancialMessageDetector().isPotentialFinancialMessage(
      'fixture',
      '[-EVCPLUS-] \$58 ayaad uwareejisay TEST USER',
    ), isTrue);
    expect(result?.candidate.provider, 'EVC Plus');
    expect(result?.candidate.type, CandidateType.expense);
  });

  test('JEEB marker passes the full detector and pipeline', () {
    final pipeline = FinancialSmsPipeline(
      FinancialSmsParserRegistry([
        EvcPlusParser(),
        JeebParser(),
        GenericFinancialParser(),
      ]),
    );
    final result = pipeline.process(
      sender: 'fixture',
      message:
          '[-JEEB-] \$0.5 ayaad u dirtay TEST PERSON(610000000),Tar: 29/09/2026 20:41:55:142',
      receivedAt: DateTime.utc(2026, 9, 29),
    );
    expect(result?.candidate.provider, 'JEEB');
    expect(result?.candidate.type, CandidateType.expense);
  });

  test('provider parsers tolerate spacing/case and fall back on bad dates', () {
    final received = DateTime.utc(2026, 9, 30, 8, 0);
    final candidate = JeebParser().parse(
      sender: 'fixture',
      message:
          '[- JEEB -] \$1 AYAAD   U   DIRTAY  TEST   PERSON(610000000),Tar: 31/02/2026 20:41:55:142',
      receivedAt: received,
    );
    expect(candidate?.amountMinor, 100);
    expect(candidate?.merchant, 'TEST PERSON');
    expect(candidate?.transactionDate, received);
    expect(candidate?.confidence, .88);
  });

  test('money formatter uses symbols for display while retaining ISO codes', () {
    MoneyFormatter.configure('USD');
    expect(MoneyFormatter.currencyCode, 'USD');
    expect(MoneyFormatter.format(5800), '\$58.00');
    expect(MoneyFormatter.format(50), '\$0.50');
    expect(MoneyFormatter.signed(4000, negative: true), '-\$40.00');
    expect(MoneyFormatter.signed(15000, negative: false), '+\$150.00');
    MoneyFormatter.configure('KES');
  });
}
