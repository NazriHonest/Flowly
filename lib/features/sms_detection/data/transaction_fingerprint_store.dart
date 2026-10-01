import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class TransactionFingerprintStore {
  const TransactionFingerprintStore(this._database);
  final AppDatabase _database;
  Future<bool> exists(String fingerprint) async =>
      Sqflite.firstIntValue(
        await (await _database.db).rawQuery(
          'SELECT COUNT(*) FROM transaction_fingerprints WHERE fingerprint=?',
          [fingerprint],
        ),
      )! >
      0;
  Future<void> save(String fingerprint, int transactionId) async =>
      (await _database.db).insert('transaction_fingerprints', {
        'fingerprint': fingerprint,
        'transaction_id': transactionId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
}
