import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV8 implements DatabaseMigration {
  @override
  int get version => 8;
  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE accounts ADD COLUMN type TEXT NOT NULL DEFAULT 'cash'",
    );
    await database.execute(
      "ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'",
    );
    await database.execute(
      'ALTER TABLE accounts ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
    );
    await database.execute(
      'ALTER TABLE accounts ADD COLUMN provider_id INTEGER',
    );
  }
}
