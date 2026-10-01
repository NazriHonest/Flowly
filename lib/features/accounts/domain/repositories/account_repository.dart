import '../entities/account.dart';

abstract interface class AccountRepository {
  Future<List<Account>> getActive();
  Future<void> save(Account account);
  Future<void> archive(int id);
}
