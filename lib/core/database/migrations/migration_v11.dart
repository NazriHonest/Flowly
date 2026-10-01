import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV11 implements DatabaseMigration {
  @override
  int get version => 11;
  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE recurring_transactions ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
    );
    await database.execute(
      'ALTER TABLE recurring_transactions ADD COLUMN start_date TEXT',
    );
  }
}
