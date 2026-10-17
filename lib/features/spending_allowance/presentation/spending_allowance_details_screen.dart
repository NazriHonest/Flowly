import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/spending_allowance.dart';
import '../domain/services/spending_allowance_calculator.dart';
import '../providers/spending_allowance_provider.dart';
import 'allowance_ui.dart';
import 'spending_allowance_history_screen.dart';
import 'spending_allowance_setup_screen.dart';

class SpendingAllowanceDetailsScreen extends ConsumerStatefulWidget {
  const SpendingAllowanceDetailsScreen({super.key});
  @override
  ConsumerState<SpendingAllowanceDetailsScreen> createState() => _State();
}

class _State extends ConsumerState<SpendingAllowanceDetailsScreen> {
  AllowancePeriodType selected = AllowancePeriodType.monthly;
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(currentAllowanceProvider).value;
    final available = <AllowancePeriodType>[
      AllowancePeriodType.monthly,
      if (config?.weeklyEnabled == true) AllowancePeriodType.weekly,
      if (config?.dailyEnabled == true) AllowancePeriodType.daily,
    ];
    if (!available.contains(selected)) selected = AllowancePeriodType.monthly;
    final summary = ref.watch(allowanceSummaryProvider(selected));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Allowance'),
        actions: [
          IconButton(
            tooltip: 'Edit allowance',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SpendingAllowanceSetupScreen(),
              ),
            ),
          ),
        ],
      ),
      body: config == null
          ? _Empty(
              onSet: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SpendingAllowanceSetupScreen(),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 48),
              children: [
                SegmentedButton<AllowancePeriodType>(
                  segments: available
                      .map(
                        (type) => ButtonSegment(
                          value: type,
                          label: Text(allowanceTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  selected: {selected},
                  onSelectionChanged: (value) =>
                      setState(() => selected = value.first),
                ),
                const SizedBox(height: 18),
                summary.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Text('Could not load this allowance period.'),
                  data: (value) => value == null
                      ? const Text('No limit is configured for this period.')
                      : _Details(summary: value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('View History'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SpendingAllowanceHistoryScreen(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.summary});
  final SpendingAllowanceSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionListProvider).value ?? [];
    final eligible = SpendingAllowanceCalculator.eligibleTransactions(
      transactions,
      summary.period,
    ).toList()..sort((a, b) => b.date.compareTo(a.date));
    final format = DateFormat(
      summary.type == AllowancePeriodType.daily ? 'EEEE, MMMM d' : 'MMM d, y',
    );
    final periodText = summary.type == AllowancePeriodType.daily
        ? format.format(summary.period.start)
        : '${format.format(summary.period.start)} – ${format.format(summary.period.end.subtract(const Duration(days: 1)))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          periodText,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: AllowanceSummaryBody(summary: summary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recorded expenses',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (eligible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No eligible expenses were recorded in this period.'),
            ),
          )
        else
          ...eligible.map(
            (transaction) => TransactionCard(
              transaction: transaction,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TransactionDetailsScreen(transaction: transaction),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSet});
  final VoidCallback onSet;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Set your spending allowance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a monthly spending limit and optionally add weekly and daily limits.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onSet, child: const Text('Set Allowance')),
        ],
      ),
    ),
  );
}
