import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV9 implements DatabaseMigration {
  @override
  int get version => 9;
  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE recurring_transactions ADD COLUMN title TEXT NOT NULL DEFAULT 'Recurring transaction'",
    );
    await database.execute(
      'ALTER TABLE recurring_transactions ADD COLUMN end_date TEXT',
    );
    await database.execute(
      'ALTER TABLE recurring_transactions ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
    );
  }
}
