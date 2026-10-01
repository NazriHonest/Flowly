import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV10 implements DatabaseMigration {
  @override
  int get version => 10;
  @override
  Future<void> apply(Database database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS recurring_occurrences(recurring_id INTEGER NOT NULL,occurrence_date TEXT NOT NULL,transaction_id INTEGER NOT NULL,PRIMARY KEY(recurring_id,occurrence_date))',
    );
  }
}
