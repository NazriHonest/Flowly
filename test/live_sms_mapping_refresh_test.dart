import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/core/database/app_database.dart';
import 'package:flowly/features/accounts/domain/entities/account.dart';
import 'package:flowly/features/sms_detection/data/automatic_transaction_processor.dart';
import 'package:flowly/features/sms_detection/data/sms_event_bridge.dart';
import 'package:flowly/features/sms_detection/domain/entities/sms_provider.dart';
import 'package:flowly/features/sms_detection/domain/services/financial_sms_parser_registry.dart';
import 'package:flowly/features/sms_detection/domain/services/financial_sms_pipeline.dart';
import 'package:flowly/features/sms_detection/parsers/evc_plus_parser.dart';
import 'package:flowly/features/sms_detection/parsers/generic_financial_parser.dart';
import 'package:flowly/features/sms_detection/parsers/jeeb_parser.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'notifications.needsReview': false,
  });
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'live processor reads mappings created after listener initialization',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flowly-live-map-',
      );
      final database = AppDatabase.forTesting(
        '${directory.path}${Platform.pathSeparator}flowly.db',
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      final processor = AutomaticTransactionProcessor(
        pipeline: FinancialSmsPipeline(
          FinancialSmsParserRegistry([
            EvcPlusParser(),
            JeebParser(),
            GenericFinancialParser(),
          ]),
        ),
        database: database,
      );

      await database.saveAccount(
        const Account(
          name: 'Wallet',
          openingBalanceMinor: 0,
          currency: 'USD',
        ),
      );
      await database.saveSmsProvider(
        const SmsProvider(name: 'JEEB', senderAliases: ['fixture']),
      );
      final account = (await database.accounts()).single;
      final provider = (await database.smsProviders()).single;
      await database.setProviderAccountMapping(provider.id!, account.id!);

      final saved = await processor.handle(
        SmsEvent(
          sender: 'fixture',
          body: '[-JEEB-] \$3 ayaad ka Heshay 252600000000,29/09/2026 21:21:16 via Local Clearing House, Haraagaagu waa \$3.48.',
          receivedAt: DateTime.utc(2026, 9, 29, 21, 21, 17),
        ),
      );

      expect(saved, isTrue);
      expect((await database.transactions()).single.accountId, account.id);
    },
  );
}
