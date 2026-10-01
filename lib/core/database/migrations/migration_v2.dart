import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV2 implements DatabaseMigration {
  @override
  int get version => 2;
  @override
  Future<void> apply(Database d) async {
    await d.execute(
      'CREATE TABLE IF NOT EXISTS categories(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE,icon INTEGER NOT NULL,color INTEGER NOT NULL,type TEXT NOT NULL,is_archived INTEGER NOT NULL DEFAULT 0)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS tx_account_idx ON transactions(account_id)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS tx_type_idx ON transactions(type)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS tx_source_idx ON transactions(source)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS tx_status_idx ON transactions(status)',
    );
  }
}
