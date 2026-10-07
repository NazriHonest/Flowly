import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../data/automatic_transaction_processor.dart';
import '../data/sms_event_bridge.dart';
import '../domain/services/financial_sms_pipeline_factory.dart';

const _backgroundChannel = MethodChannel('com.flowly/sms_background');

Future<void> runSmsBackgroundWorker() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.db;

  final processor = AutomaticTransactionProcessor(
    pipeline: createFinancialSmsPipeline(),
    database: AppDatabase.instance,
  );

  _backgroundChannel.setMethodCallHandler((call) async {
    if (call.method != 'processRows') return null;
    final arguments = (call.arguments as List<Object?>?) ?? const [];
    var changed = false;
    var retry = false;
    int? acknowledgedId;
    int? acknowledgedAt;

    for (final value in arguments) {
      final enabled =
          await _backgroundChannel.invokeMethod<bool>(
            'isAutomaticDetectionEnabled',
          ) ??
          false;
      if (!enabled) break;
      if (value is! Map) continue;
      final row = Map<Object?, Object?>.from(value);
      final id = row['id'] as int?;
      final receivedAt = row['receivedAt'] as int?;
      if (id == null || receivedAt == null) continue;

      final outcome = await processor.handle(
        SmsEvent(
          sender: row['sender'] as String? ?? '',
          body: row['body'] as String? ?? '',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAt),
        ),
      );
      if (!outcome.advancesCursor) {
        retry = true;
        developer.log('retry_scheduled', name: 'FlowlySMS');
        break;
      }

      acknowledgedId = id;
      acknowledgedAt = receivedAt;
      changed = changed || outcome.databaseChanged;
    }

    return <String, Object?>{
      'retry': retry,
      'changed': changed,
      if (acknowledgedId != null) 'acknowledgedId': acknowledgedId,
      if (acknowledgedAt != null) 'acknowledgedAt': acknowledgedAt,
    };
  });

  await _backgroundChannel.invokeMethod<void>('backgroundReady');
}
