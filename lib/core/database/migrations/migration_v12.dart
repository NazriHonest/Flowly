import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';

class MigrationV12 implements DatabaseMigration {
  @override
  int get version => 12;

  @override
  Future<void> apply(Database database) async {
    await database.execute(
      "ALTER TABLE sms_providers ADD COLUMN sender_aliases TEXT NOT NULL DEFAULT ''",
    );
  }
}
