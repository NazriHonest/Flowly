import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/budget.dart';
import '../providers/budget_provider.dart';
import 'budget_form_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetListProvider);
    final transactions = ref.watch(transactionListProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 19),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetFormScreen()),
              ),
            ),
          ),
        ],
      ),
      body: budgets.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load budgets',
          message: 'Please check your connection and try again.',
          onRetry: () => ref.invalidate(budgetListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.savings_outlined,
              message: 'Create a budget to track category spending.',
            );
          }
          final total = items.fold<int>(0, (sum, b) => sum + b.amountMinor);
          final spent = items.fold<int>(
            0,
            (sum, b) => sum + _spent(b, transactions),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _BudgetOverview(spent: spent, total: total),
              const SizedBox(height: 14),
              ...items.map(
                (budget) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BudgetCard(
                    budget: budget,
                    spent: _spent(budget, transactions),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BudgetDetailsScreen(budget: budget),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BudgetDetailsScreen extends ConsumerWidget {
  const BudgetDetailsScreen({super.key, required this.budget});
  final Budget budget;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionListProvider).value ?? [];
    final related =
        transactions
            .where(
              (t) =>
                  t.status == ReviewStatus.confirmed &&
                  t.type == TransactionType.expense &&
                  t.category == budget.category,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final spent = related.fold<int>(0, (sum, t) => sum + t.amountMinor);
    final ratio = budget.amountMinor == 0 ? 0.0 : spent / budget.amountMinor;
    final color = _progressColor(ratio, budget.alertThreshold);
    final remaining = (budget.amountMinor - spent).clamp(0, budget.amountMinor);
    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          _RoundAction(
            icon: Icons.edit_outlined,
            label: 'Edit budget',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BudgetFormScreen(budget: budget),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RoundAction(
            icon: Icons.archive_outlined,
            label: 'Archive budget',
            onTap: () async {
              if (!await showFlowlyConfirmation(
                context,
                title: 'Archive budget?',
                message: 'This budget will be removed from active tracking.',
                confirmLabel: 'Archive budget',
              )) {
                return;
              }
              await ref.read(budgetListProvider.notifier).archive(budget.id!);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: _ProgressRing(
              value: ratio,
              color: color,
              main: '${(ratio * 100).round()}%',
              label: 'Spent',
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              MoneyFormatter.format(spent),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Center(
            child: Text(
              '${MoneyFormatter.format(remaining)} remaining',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
          _DetailsTable(
            rows: [
              ('Category', budget.category),
              ('Budget', MoneyFormatter.format(budget.amountMinor)),
              ('Period', _capitalize(budget.period)),
              ('Start date', _date(budget.startDate)),
              ('Alert threshold', '${(budget.alertThreshold * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Related transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (related.isEmpty)
            const _EmptyRelatedTransactions()
          else
            ...related.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TransactionCard(transaction: t),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.spent, required this.total});
  final int spent, total;
  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : spent / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      decoration: _box(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('October total', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 1),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge,
              children: [
                TextSpan(text: MoneyFormatter.format(spent)),
                TextSpan(
                  text: ' of ${MoneyFormatter.format(total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onTap,
  });
  final Budget budget;
  final int spent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ratio = budget.amountMinor == 0 ? 0.0 : spent / budget.amountMinor;
    final color = _progressColor(ratio, budget.alertThreshold);
    final remaining = (budget.amountMinor - spent).clamp(0, budget.amountMinor);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _box(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryIcon(category: budget.category, color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${MoneyFormatter.format(spent)} / ${MoneyFormatter.format(budget.amountMinor)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    text: ratio >= 1
                        ? 'Limit exceeded'
                        : ratio >= budget.alertThreshold
                        ? 'Near limit · ${(ratio * 100).round()}%'
                        : 'On track · ${(ratio * 100).round()}%',
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  color: color,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${MoneyFormatter.format(remaining)} remaining',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color),
                  ),
                  const Spacer(),
                  Text(
                    _capitalize(budget.period),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.color,
    required this.main,
    required this.label,
  });
  final double value;
  final Color color;
  final String main, label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    height: 110,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CircularProgressIndicator(
            value: value.clamp(0, 1),
            color: color,
            backgroundColor: color.withValues(alpha: .08),
            strokeWidth: 9,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              main,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    ),
  );
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _box(context),
    child: Column(
      children: rows.indexed.map((entry) {
        final (index, row) = entry;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : Border(
                    top: BorderSide(
                      color: AppColors.lightBorder.withValues(alpha: .7),
                    ),
                  ),
          ),
          child: Row(
            children: [
              Text(row.$1, style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text(
                row.$2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: _box(context),
    child: Row(
      children: [
        _CategoryIcon(category: transaction.category, color: AppColors.expense),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${transaction.category} · ${_date(transaction.date)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Text(
          MoneyFormatter.signed(transaction.amountMinor, negative: true),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.lightTextSecondary,
          ),
        ),
      ],
    ),
  );
}

class _EmptyRelatedTransactions extends StatelessWidget {
  const _EmptyRelatedTransactions();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _box(context),
    child: Text(
      'No related transactions yet.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.lightBorder),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w800),
    ),
  );
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.color});
  final String category;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(7),
    ),
    alignment: Alignment.center,
    child: Icon(_iconFor(category), size: 15, color: color),
  );
}

BoxDecoration _box(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: AppColors.lightBorder),
);
int _spent(Budget budget, List<Transaction> transactions) => transactions
    .where(
      (t) =>
          t.status == ReviewStatus.confirmed &&
          t.type == TransactionType.expense &&
          t.category == budget.category,
    )
    .fold<int>(0, (sum, t) => sum + t.amountMinor);
Color _progressColor(double ratio, double threshold) => ratio >= 1
    ? AppColors.expense
    : ratio >= threshold
    ? AppColors.warning
    : AppColors.primary;
String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
String _date(DateTime? date) => date == null
    ? 'Not set'
    : '${_month(date.month)} ${date.day}, ${date.year}';
String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
IconData _iconFor(String category) {
  final value = category.toLowerCase();
  if (value.contains('food') || value.contains('dining')) {
    return Icons.restaurant_rounded;
  }
  if (value.contains('grocery')) return Icons.shopping_basket_rounded;
  if (value.contains('transport')) return Icons.directions_car_filled_rounded;
  if (value.contains('entertain')) return Icons.movie_rounded;
  return Icons.pie_chart_rounded;
}
