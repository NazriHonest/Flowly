import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/recurring_transaction.dart';

class RecurringController
    extends StateNotifier<AsyncValue<List<RecurringTransaction>>> {
  RecurringController() : super(const AsyncLoading()) {
    refresh();
  }
  Future<void> refresh() async =>
      state = AsyncData(await AppDatabase.instance.recurringTransactions());
  Future<void> save(RecurringTransaction item) async {
    await AppDatabase.instance.saveRecurringTransaction(item);
    await refresh();
  }

  Future<void> archive(int id) async {
    await AppDatabase.instance.archiveRecurringTransaction(id);
    await refresh();
  }
}

final recurringListProvider =
    StateNotifierProvider<
      RecurringController,
      AsyncValue<List<RecurringTransaction>>
    >((_) => RecurringController());
