import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/datasources/account_local_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../domain/entities/account.dart';
import '../domain/repositories/account_repository.dart';

class AccountController extends StateNotifier<AsyncValue<List<Account>>> {
  AccountController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }
  final AccountRepository _repository;
  Future<void> refresh() async =>
      state = AsyncData(await _repository.getActive());
  Future<void> save(Account a) async {
    await _repository.save(a);
    await refresh();
  }

  Future<void> archive(int id) async {
    await _repository.archive(id);
    await refresh();
  }
}

final accountListProvider =
    StateNotifierProvider<AccountController, AsyncValue<List<Account>>>(
      (_) => AccountController(
        AccountRepositoryImpl(AccountLocalDataSource(AppDatabase.instance)),
      ),
    );
