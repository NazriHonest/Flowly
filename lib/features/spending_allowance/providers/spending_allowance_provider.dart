import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../data/spending_allowance_repository.dart';
import '../domain/entities/spending_allowance.dart';
import '../domain/services/spending_allowance_calculator.dart';

final spendingAllowanceRepositoryProvider = Provider(
  (_) => SpendingAllowanceRepository(AppDatabase.instance),
);

final currentAllowanceProvider = FutureProvider<SpendingAllowanceConfig?>((ref) {
  return ref.read(spendingAllowanceRepositoryProvider).configurationFor(DateTime.now());
});

final allowanceSummaryProvider = FutureProvider.family<SpendingAllowanceSummary?, AllowancePeriodType>(
  (ref, type) async {
    final transactionState = ref.watch(transactionListProvider);
    final transactions =
        transactionState.valueOrNull ??
        await ref.read(transactionRepositoryProvider).getAll();
    final now = DateTime.now();
    final period = SpendingAllowanceCalculator.periodFor(type, now);
    final effectiveDate = type == AllowancePeriodType.monthly ? now : period.start;
    final config = await ref.read(spendingAllowanceRepositoryProvider).configurationFor(effectiveDate);
    final limit = config?.limitFor(type);
    if (limit == null) return null;
    return SpendingAllowanceCalculator.calculate(
      type: type,
      allowanceMinor: limit,
      transactions: transactions,
      at: now,
    );
  },
);

final selectedDashboardAllowancePeriodProvider =
    StateProvider<AllowancePeriodType>((_) => AllowancePeriodType.monthly);

class SpendingAllowanceMutations {
  const SpendingAllowanceMutations(this.ref);
  final Ref ref;

  Future<void> save(SpendingAllowanceConfig config) async {
    await ref.read(spendingAllowanceRepositoryProvider).save(config);
    ref.invalidate(currentAllowanceProvider);
    for (final type in AllowancePeriodType.values) {
      ref.invalidate(allowanceSummaryProvider(type));
    }
  }
}

final spendingAllowanceMutationsProvider = Provider(SpendingAllowanceMutations.new);
