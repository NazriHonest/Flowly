import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Adds the receiving side of an internal transfer without duplicating the
/// transaction or treating it as income/expense.
class MigrationV5 implements DatabaseMigration {
  @override
  int get version => 5;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      'ALTER TABLE transactions ADD COLUMN destination_account_id INTEGER REFERENCES accounts(id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS tx_destination_account_idx ON transactions(destination_account_id)',
    );
  }
}
