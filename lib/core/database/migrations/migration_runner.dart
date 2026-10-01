import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';
import 'migration_v5.dart';
import 'migration_v6.dart';
import 'migration_v7.dart';
import 'migration_v8.dart';
import 'migration_v9.dart';
import 'migration_v10.dart';
import 'migration_v11.dart';
import 'migration_v12.dart';
import 'migration_v13.dart';
import 'migration_v14.dart';
import 'migration_v15.dart';

class MigrationRunner {
  const MigrationRunner();
  static final migrations = <DatabaseMigration>[
    MigrationV1(),
    MigrationV2(),
    MigrationV3(),
    MigrationV4(),
    MigrationV5(),
    MigrationV6(),
    MigrationV7(),
    MigrationV8(),
    MigrationV9(),
    MigrationV10(),
    MigrationV11(),
    MigrationV12(),
    MigrationV13(),
    MigrationV14(),
    MigrationV15(),
  ];
  Future<void> run(Database database, {required int from}) async {
    for (final migration in migrations.where((m) => m.version > from)) {
      await migration.apply(database);
    }
  }

  Future<void> create(Database database) async {
    for (final migration in migrations) {
      await migration.apply(database);
    }
  }
}
