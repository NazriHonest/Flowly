import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Stores a reversible relationship between the two independently captured SMS
/// records. The original normalized records remain in `transactions`.
class MigrationV15 implements DatabaseMigration {
  @override
  int get version => 15;

  @override
  Future<void> apply(Database database) => database.execute('''
    CREATE TABLE transfer_reconciliations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      outgoing_transaction_id INTEGER NOT NULL UNIQUE,
      incoming_transaction_id INTEGER NOT NULL UNIQUE,
      outgoing_snapshot TEXT NOT NULL,
      incoming_snapshot TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(outgoing_transaction_id) REFERENCES transactions(id),
      FOREIGN KEY(incoming_transaction_id) REFERENCES transactions(id)
    )
  ''');
}
