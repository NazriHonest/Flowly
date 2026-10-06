import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/transfer_candidate_provider.dart';
import '../data/automatic_transaction_processor.dart';
import '../data/sms_event_bridge.dart';
import '../domain/services/financial_sms_parser_registry.dart';
import '../domain/services/financial_sms_pipeline.dart';
import '../parsers/evc_plus_parser.dart';
import '../parsers/agro_bank_parser.dart';
import '../parsers/deeqtoon_parser.dart';
import '../parsers/generic_financial_parser.dart';
import '../parsers/jeeb_parser.dart';
import 'automatic_detection_provider.dart';

/// Keeps native SMS delivery opt-in: events only exist after Android permission
/// is granted, and this listener stores normalized candidates only.
final smsLiveListenerProvider = Provider<void>((ref) {
  if (!ref.watch(automaticDetectionProvider)) {
    developer.log(
      'dart_listener_inactive_detection_disabled',
      name: 'FlowlySMS',
    );
    return;
  }
  developer.log('dart_listener_start', name: 'FlowlySMS');
  final processor = AutomaticTransactionProcessor(
    pipeline: FinancialSmsPipeline(
      FinancialSmsParserRegistry([
        EvcPlusParser(),
        JeebParser(),
        DeeqtoonParser(),
        AgroBankParser(),
        GenericFinancialParser(),
      ]),
    ),
    database: AppDatabase.instance,
  );
  final StreamSubscription subscription = SmsEventBridge().events.listen(
    (event) async {
      try {
        if (await processor.handle(event)) {
          await ref.read(transactionListProvider.notifier).refresh();
          await ref.read(pendingSmsTransferListProvider.notifier).refresh();
          developer.log('state_refresh_complete', name: 'FlowlySMS');
        }
      } catch (error, stackTrace) {
        // Do not include the event: it contains raw SMS content. Persistence
        // and its fingerprint are atomic, so a failure remains importable.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Flowly live SMS processing',
            context: ErrorDescription('while processing a normalized SMS'),
          ),
        );
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Flowly SMS event channel',
          context: ErrorDescription('while receiving an SMS event'),
        ),
      );
    },
  );
  developer.log('dart_listener_attached', name: 'FlowlySMS');
  ref.onDispose(subscription.cancel);
});
