import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../data/automatic_transaction_processor.dart';
import '../data/sms_event_bridge.dart';
import '../domain/services/financial_sms_parser_registry.dart';
import '../domain/services/financial_sms_pipeline.dart';
import '../parsers/evc_plus_parser.dart';
import '../parsers/generic_financial_parser.dart';
import '../parsers/jeeb_parser.dart';
import 'automatic_detection_provider.dart';

/// Keeps native SMS delivery opt-in: events only exist after Android permission
/// is granted, and this listener stores normalized candidates only.
final smsLiveListenerProvider = Provider<void>((ref) {
  if (!ref.watch(automaticDetectionProvider)) return;
  final processor = AutomaticTransactionProcessor(
    pipeline: FinancialSmsPipeline(
      FinancialSmsParserRegistry([
        EvcPlusParser(),
        JeebParser(),
        GenericFinancialParser(),
      ]),
    ),
    database: AppDatabase.instance,
  );
  final StreamSubscription subscription = SmsEventBridge().events.listen((
    event,
  ) async {
    if (await processor.handle(event)) {
      await ref.read(transactionListProvider.notifier).refresh();
    }
  });
  ref.onDispose(subscription.cancel);
});
