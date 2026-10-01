import '../../../../core/database/app_database.dart';
import '../../domain/entities/account.dart';

/// SQLite boundary for the accounts feature.
class AccountLocalDataSource {
  const AccountLocalDataSource(this._database);

  final AppDatabase _database;

  Future<List<Account>> getActive() => _database.accounts();
  Future<void> save(Account account) => _database.saveAccount(account);
  Future<void> archive(int id) => _database.archiveAccount(id);
}
