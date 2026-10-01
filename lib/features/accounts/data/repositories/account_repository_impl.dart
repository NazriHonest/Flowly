import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_local_datasource.dart';

class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._local);

  final AccountLocalDataSource _local;

  @override
  Future<List<Account>> getActive() => _local.getActive();

  @override
  Future<void> save(Account account) => _local.save(account);

  @override
  Future<void> archive(int id) => _local.archive(id);
}
