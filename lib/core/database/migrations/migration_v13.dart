import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Adds privacy-safe normalized SMS metadata. No message body or sender is
/// copied into the transaction table.
class MigrationV13 implements DatabaseMigration {
  @override
  int get version => 13;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      'ALTER TABLE transactions ADD COLUMN provider_transaction_at TEXT',
    );
    await database.execute(
      'ALTER TABLE transactions ADD COLUMN sms_received_at TEXT',
    );
    await database.execute('ALTER TABLE transactions ADD COLUMN created_at TEXT');
    // Detected transactions already have a trustworthy persistence time in the
    // fingerprint table. Preserve it where it exists; old manual records stay
    // null rather than being assigned an invented creation time.
    await database.execute('''
      UPDATE transactions
      SET created_at = (
        SELECT created_at FROM transaction_fingerprints
        WHERE transaction_fingerprints.transaction_id = transactions.id
      )
      WHERE created_at IS NULL
    ''');
    // Before this migration `transaction_date` was already the provider time
    // when parsers could read one. Its validity cannot be reconstructed, so
    // old rows deliberately retain only their display transaction date.
  }
}
