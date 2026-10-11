import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/providers/category_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/recurring_forecast.dart';
import '../domain/entities/recurring_transaction.dart';
import '../domain/services/recurring_forecast_service.dart';

class RecurringController
    extends StateNotifier<AsyncValue<List<RecurringTransaction>>> {
  RecurringController({
    AppDatabase? database,
    List<RecurringTransaction>? initialItems,
  }) : _database = database ?? AppDatabase.instance,
       super(
         initialItems == null
             ? const AsyncLoading()
             : AsyncData(List.unmodifiable(initialItems)),
       ) {
    if (initialItems == null) refresh();
  }

  final AppDatabase _database;

  Future<void> refresh() async =>
      state = AsyncData(await _database.recurringTransactions());
  Future<void> save(RecurringTransaction item) async {
    await _database.saveRecurringTransaction(item);
    await refresh();
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await _database.setRecurringTransactionEnabled(id, enabled);
    await refresh();
  }

  Future<void> archive(int id) async {
    await _database.archiveRecurringTransaction(id);
    await refresh();
  }
}

final recurringListProvider =
    StateNotifierProvider<
      RecurringController,
      AsyncValue<List<RecurringTransaction>>
    >((_) => RecurringController());

final recurringCategoriesProvider = Provider<List<Category>>(
  (ref) => ref.watch(categoryListProvider).valueOrNull ?? const [],
);

final recurringTodayProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  ),
);

final upcomingRecurringOccurrencesProvider =
    Provider.autoDispose<List<RecurringOccurrence>>((ref) {
      final schedules =
          ref.watch(recurringListProvider).valueOrNull ?? const [];
      final now =
          ref.watch(recurringTodayProvider).valueOrNull ?? DateTime.now();
      return const RecurringForecastService().upcoming(schedules, from: now);
    });

final monthlyRecurringCommitmentsProvider = Provider.autoDispose
    .family<MonthlyRecurringCommitments, DateTime>((ref, month) {
      final schedules =
          ref.watch(recurringListProvider).valueOrNull ?? const [];
      return const RecurringForecastService().commitments(schedules, month);
    });

final recurringPaymentHistoryProvider = FutureProvider.autoDispose
    .family<List<Transaction>, int>((ref, recurringId) async {
      ref.watch(transactionListProvider);
      return AppDatabase.instance.recurringTransactionHistory(recurringId);
    });
