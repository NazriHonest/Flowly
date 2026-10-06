import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/sms_detection/domain/entities/transaction_candidate.dart';
import 'package:flowly/features/sms_detection/parsers/agro_bank_parser.dart';
import 'package:flowly/features/sms_detection/parsers/deeqtoon_parser.dart';
import 'package:flowly/features/sms_detection/parsers/evc_plus_parser.dart';
import 'package:flowly/features/sms_detection/parsers/jeeb_parser.dart';

void main() {
  final received = DateTime.utc(2026, 10, 6, 12);

  test('JEEB wallet to bank is an outgoing internal transfer', () {
    final candidate = JeebParser().parse(
      sender: 'JEEB',
      message: r'[-JEEB-] Waxaad $10 ku shubtey bank account-kaaga: 201XXX04, Haraagaaga waa $0.33.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'JEEB',
      amount: 1000,
      direction: TransferObservationDirection.outgoing,
      timestamp: null,
    );
  });

  test('bank to JEEB is an incoming internal transfer', () {
    final candidate = JeebParser().parse(
      sender: 'JEEB',
      message: r'[-JEEB-] waxaad kala baxday $30 Xisaabtaada bangiga No: 201XXX04, haraagaagu waa  $30.03.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'JEEB',
      amount: 3000,
      direction: TransferObservationDirection.incoming,
      timestamp: null,
    );
  });

  test('AGROBANK deposit parses bank-side incoming and timestamp', () {
    final candidate = AgroBankParser().parse(
      sender: 'AGROBANK',
      message: 'USD 10 ayaa dhigatay koontadaada bangiga ee (201XXX04), xilliga: 06-Oct-26 11:13:58, Waad ku mahadsanthay isticmaalka adeega BURAAQ.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'AGROBANK',
      amount: 1000,
      direction: TransferObservationDirection.incoming,
      timestamp: DateTime(2026, 10, 6, 11, 13, 58),
    );
  });

  test('AGROBANK withdrawal parses bank-side outgoing and one-digit hour', () {
    final candidate = AgroBankParser().parse(
      sender: 'AGROBANK',
      message: 'USD 30 ayaa kala baxday koontadaada bangiga ee (201XXX04), xilliga: 06-Oct-26 9:57:06, Waad ku mahadsanthay isticmaalka adeega BURAAQ.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'AGROBANK',
      amount: 3000,
      direction: TransferObservationDirection.outgoing,
      timestamp: DateTime(2026, 10, 6, 9, 57, 6),
    );
  });

  test('EVC Plus wallet to bank is an outgoing internal transfer', () {
    final candidate = EvcPlusParser().parse(
      sender: 'EVCPlus',
      message: r'[-EVCPlus-] Waxaad $15 ku shubtey bank account-kaaga: 374XXX91, Haraagaaga waa $18.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'EVC Plus',
      amount: 1500,
      direction: TransferObservationDirection.outgoing,
      timestamp: null,
    );
  });

  test('bank to EVC Plus is an incoming internal transfer', () {
    final candidate = EvcPlusParser().parse(
      sender: 'EVCPlus',
      message: r'[-EVCPlus-] waxaad kala baxday $15 Xisaabtaada bangiga No: 374XXX91, haraagaagu waa  $160.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'EVC Plus',
      amount: 1500,
      direction: TransferObservationDirection.incoming,
      timestamp: null,
    );
  });

  test('DEEQTOON deposit parses incoming and 12-hour timestamp', () {
    final candidate = DeeqtoonParser().parse(
      sender: 'DEEQTOON',
      message: 'USD 15 ayaa dhigatay koontadaada bangiga ee (374XXX91), xilliga: 27/09/2026 3:19:41 PM, Waad ku mahadsanthay isticmaalka adeega DEEQTOON.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'DEEQTOON',
      amount: 1500,
      direction: TransferObservationDirection.incoming,
      timestamp: DateTime(2026, 9, 27, 15, 19, 41),
    );
  });

  test('DEEQTOON withdrawal parses outgoing and AM timestamp', () {
    final candidate = DeeqtoonParser().parse(
      sender: 'DEEQTOON',
      message: 'USD 15 ayaa kala baxday koontadaada bangiga ee (374XXX91), xilliga: 28/09/2026 10:11:01 AM, Waad ku mahadsanthay isticmaalka adeega DEEQTOON.',
      receivedAt: received,
    );
    _expectTransfer(
      candidate,
      provider: 'DEEQTOON',
      amount: 1500,
      direction: TransferObservationDirection.outgoing,
      timestamp: DateTime(2026, 9, 28, 10, 11, 1),
    );
  });

  test('matching masked identifiers produce equal non-reversible hints', () {
    final wallet = JeebParser().parse(
      sender: 'JEEB',
      message: r'[-JEEB-] Waxaad $10 ku shubtey bank account-kaaga: 201XXX04, Haraagaaga waa $0.33.',
      receivedAt: received,
    );
    final bank = AgroBankParser().parse(
      sender: 'AGROBANK',
      message: 'USD 10 ayaa dhigatay koontadaada bangiga ee (201XXX04), xilliga: 06-Oct-26 11:13:58, Waad ku mahadsanthay isticmaalka adeega BURAAQ.',
      receivedAt: received,
    );
    expect(wallet!.accountHintHash, bank!.accountHintHash);
    expect(wallet.accountHintHash, hasLength(64));
    expect(wallet.accountHintHash, isNot(contains('201')));
  });
}

void _expectTransfer(
  TransactionCandidate? candidate, {
  required String provider,
  required int amount,
  required TransferObservationDirection direction,
  required DateTime? timestamp,
}) {
  expect(candidate, isNotNull);
  expect(candidate!.provider, provider);
  expect(candidate.amountMinor, amount);
  expect(candidate.currency, 'USD');
  expect(candidate.semantics, CandidateSemantics.internalTransfer);
  expect(candidate.transferDirection, direction);
  expect(candidate.providerTransactionAt, timestamp);
  expect(candidate.accountHintHash, hasLength(64));
}
