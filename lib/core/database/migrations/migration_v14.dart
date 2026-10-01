import 'package:sqflite/sqflite.dart';
import 'database_migration.dart';

class MigrationV14 implements DatabaseMigration {
  @override
  int get version => 14;
  @override
  Future<void> apply(Database database) => database.execute(
    'ALTER TABLE accounts ADD COLUMN icon INTEGER NOT NULL DEFAULT 59472',
  );
}
