import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/spending_allowance.dart';
import '../domain/services/spending_allowance_calculator.dart';
import '../providers/spending_allowance_provider.dart';
import 'allowance_ui.dart';

class SpendingAllowanceHistoryScreen extends ConsumerStatefulWidget {
  const SpendingAllowanceHistoryScreen({super.key});
  @override ConsumerState<SpendingAllowanceHistoryScreen> createState() => _State();
}
class _State extends ConsumerState<SpendingAllowanceHistoryScreen> {
  AllowancePeriodType type = AllowancePeriodType.monthly;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Allowance History')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: SegmentedButton<AllowancePeriodType>(segments: AllowancePeriodType.values.map((v) => ButtonSegment(value: v, label: Text(allowanceTypeLabel(v)))).toList(), selected: {type}, onSelectionChanged: (v) => setState(() => type = v.first))),
      Expanded(child: FutureBuilder<List<_HistoryItem>>(future: _load(), builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No configured allowance history for this period type.'));
        return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, index) {
          final item = items[index]; final summary = item.summary;
          return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 10), if (summary == null) Text('No limit was configured.', style: Theme.of(context).textTheme.bodyMedium) else AllowanceSummaryBody(summary: summary, compact: true)])));
        });
      })),
    ]),
  );

  Future<List<_HistoryItem>> _load() async {
    final repo = ref.read(spendingAllowanceRepositoryProvider);
    final transactionState = ref.read(transactionListProvider);
    final transactions =
        transactionState.valueOrNull ??
        await ref.read(transactionRepositoryProvider).getAll();
    final now = DateTime.now();
    final anchors = List.generate(12, (index) => switch (type) {
      AllowancePeriodType.monthly => DateTime(now.year, now.month - index),
      AllowancePeriodType.weekly => now.subtract(Duration(days: index * 7)),
      AllowancePeriodType.daily => now.subtract(Duration(days: index)),
    });
    final result = <_HistoryItem>[];
    for (final anchor in anchors) {
      final period = SpendingAllowanceCalculator.periodFor(type, anchor);
      final config = await repo.configurationFor(type == AllowancePeriodType.monthly ? anchor : period.start);
      final limit = config?.limitFor(type);
      final label = type == AllowancePeriodType.daily ? DateFormat('EEEE, MMM d, y').format(period.start) : '${DateFormat('MMM d, y').format(period.start)} – ${DateFormat('MMM d, y').format(period.end.subtract(const Duration(days: 1)))}';
      final summary = limit == null ? null : SpendingAllowanceCalculator.calculate(type: type, allowanceMinor: limit, transactions: transactions, at: anchor);
      result.add(_HistoryItem(label, summary));
    }
    return result;
  }
}
class _HistoryItem { const _HistoryItem(this.label, this.summary); final String label; final SpendingAllowanceSummary? summary; }
