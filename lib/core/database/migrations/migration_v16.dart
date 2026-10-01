import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

/// Persists conservative, user-reviewable transfer suggestions. Existing
/// transactions are never rewritten by this migration.
class MigrationV16 implements DatabaseMigration {
  @override
  int get version => 16;

  @override
  Future<void> apply(Database database) => database.execute('''
    CREATE TABLE transfer_candidates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      outgoing_transaction_id INTEGER NOT NULL,
      incoming_transaction_id INTEGER NOT NULL,
      confidence TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'possible',
      created_at TEXT NOT NULL,
      resolved_at TEXT,
      UNIQUE(outgoing_transaction_id, incoming_transaction_id),
      FOREIGN KEY(outgoing_transaction_id) REFERENCES transactions(id),
      FOREIGN KEY(incoming_transaction_id) REFERENCES transactions(id)
    )
  ''');
}
