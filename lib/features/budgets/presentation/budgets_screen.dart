import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/budget.dart';
import '../domain/services/budget_spending_calculator.dart';
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
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              tooltip: 'Add budget',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
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
          message: 'Please try again.',
          onRetry: () => ref.invalidate(budgetListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  AppLayout.safeScrollBottom(context),
                ),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.62,
                    child: AppEmptyState(
                      icon: Icons.savings_outlined,
                      title: 'No budgets yet',
                      message: 'Create a budget to set spending limits and keep your expenses on track.',
                      actionLabel: 'Create budget',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BudgetFormScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final total = items.fold<int>(
            0,
            (sum, budget) => sum + budget.amountMinor,
          );

          final spent = items.fold<int>(
            0,
            (sum, budget) => sum + _spent(budget, transactions),
          );

          final onTrackCount = items.where((budget) {
            final budgetSpent = _spent(budget, transactions);

            final ratio = budget.amountMinor == 0
                ? 0.0
                : budgetSpent / budget.amountMinor;

            return ratio < budget.alertThreshold;
          }).length;

          final warningCount = items.where((budget) {
            final budgetSpent = _spent(budget, transactions);

            final ratio = budget.amountMinor == 0
                ? 0.0
                : budgetSpent / budget.amountMinor;

            return ratio >= budget.alertThreshold && ratio < 1;
          }).length;

          final overCount = items.where((budget) {
            final budgetSpent = _spent(budget, transactions);

            final ratio = budget.amountMinor == 0
                ? 0.0
                : budgetSpent / budget.amountMinor;

            return ratio >= 1;
          }).length;

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                AppLayout.safeScrollBottom(context),
              ),
              children: [
                _BudgetOverview(
                  spent: spent,
                  total: total,
                  budgetCount: items.length,
                  onTrackCount: onTrackCount,
                  warningCount: warningCount,
                  overCount: overCount,
                ),

                const SizedBox(height: 26),

                _SectionHeader(
                  title: 'Your budgets',
                  subtitle:
                      '${items.length} active ${items.length == 1 ? 'budget' : 'budgets'}',
                ),

                const SizedBox(height: 12),

                ...items.map(
                  (budget) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(budgetListProvider.notifier).refresh();

    await ref.read(transactionListProvider.notifier).refresh();
  }
}

class BudgetDetailsScreen extends ConsumerWidget {
  const BudgetDetailsScreen({super.key, required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = budget.id == null
        ? budget
        : ref
                  .watch(budgetListProvider)
                  .valueOrNull
                  ?.where((item) => item.id == budget.id)
                  .firstOrNull ??
              budget;
    final transactions = ref.watch(transactionListProvider).value ?? [];

    final related =
        BudgetSpendingCalculator.countedTransactions(current, transactions)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final spent = BudgetSpendingCalculator.spent(current, transactions);

    final ratio = current.amountMinor == 0
        ? 0.0
        : spent / current.amountMinor;

    final color = _progressColor(ratio, current.alertThreshold);

    final difference = current.amountMinor - spent;

    final isOverBudget = difference < 0;

    final differenceAmount = difference.abs();

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          _RoundAction(
            icon: Icons.edit_outlined,
            label: 'Edit budget',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BudgetFormScreen(budget: current),
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

              await ref.read(budgetListProvider.notifier).archive(current.id!);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          _BudgetDetailsHero(
            budget: current,
            spent: spent,
            ratio: ratio,
            color: color,
            differenceAmount: differenceAmount,
            isOverBudget: isOverBudget,
          ),

          const SizedBox(height: 26),

          const _SectionHeader(
            title: 'Budget details',
            subtitle: 'Limit, period and alert information',
          ),

          const SizedBox(height: 12),

          _DetailsTable(
            rows: [
              ('Category', current.category, Icons.category_outlined),
              (
                'Budget limit',
                MoneyFormatter.format(current.amountMinor),
                Icons.account_balance_wallet_outlined,
              ),
              (
                'Period',
                _capitalize(current.period),
                Icons.calendar_month_outlined,
              ),
              ('Start date', _date(current.startDate), Icons.event_outlined),
              (
                'Alert threshold',
                '${(current.alertThreshold * 100).round()}%',
                Icons.notifications_none_rounded,
              ),
            ],
          ),

          const SizedBox(height: 26),

          _SectionHeader(
            title: 'Transactions counted this period',
            subtitle: related.isEmpty
                ? 'No qualifying spending in the active period'
                : '${related.length} ${related.length == 1 ? 'transaction' : 'transactions'}',
          ),

          const SizedBox(height: 12),

          if (related.isEmpty)
            const _EmptyRelatedTransactions()
          else
            ...related.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(transaction: transaction),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({
    required this.spent,
    required this.total,
    required this.budgetCount,
    required this.onTrackCount,
    required this.warningCount,
    required this.overCount,
  });

  final int spent;
  final int total;
  final int budgetCount;
  final int onTrackCount;
  final int warningCount;
  final int overCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ratio = total == 0 ? 0.0 : spent / total;

    final color = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
        ? AppColors.warning
        : AppColors.primary;

    final difference = total - spent;
    final isOver = difference < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget overview',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$budgetCount active ${budgetCount == 1 ? 'budget' : 'budgets'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.heroTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'TOTAL SPENT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.heroTextMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            MoneyFormatter.format(spent),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'of ${MoneyFormatter.format(total)} total budgeted',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.heroTextMuted,
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: ratio >= 1
                  ? const Color(0xFFFFB4AB)
                  : ratio >= 0.8
                  ? const Color(0xFFFFD180)
                  : Colors.white,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Text(
                '${(ratio * 100).round()}% used',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                isOver
                    ? '${MoneyFormatter.format(difference.abs())} over'
                    : '${MoneyFormatter.format(difference)} remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _OverviewStatus(
                    value: '$onTrackCount',
                    label: 'On track',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                _OverviewDivider(),
                Expanded(
                  child: _OverviewStatus(
                    value: '$warningCount',
                    label: 'Near limit',
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                _OverviewDivider(),
                Expanded(
                  child: _OverviewStatus(
                    value: '$overCount',
                    label: 'Over',
                    icon: Icons.error_outline_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatus extends StatelessWidget {
  const _OverviewStatus({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 5),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.heroTextMuted,
          ),
        ),
      ],
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.15),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final ratio = budget.amountMinor == 0 ? 0.0 : spent / budget.amountMinor;

    final color = _progressColor(ratio, budget.alertThreshold);

    final difference = budget.amountMinor - spent;

    final isOver = difference < 0;

    final status = ratio >= 1
        ? 'Over budget'
        : ratio >= budget.alertThreshold
        ? 'Near limit'
        : 'On track';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryIcon(
                    category: budget.category,
                    color: color,
                    size: 38,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '${budget.category} • ${_capitalize(budget.period)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(ratio * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 11),

              Text(
                '${MoneyFormatter.format(spent)} spent / ${MoneyFormatter.format(budget.amountMinor)} limit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 9),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.10),
                  color: color,
                ),
              ),

              const SizedBox(height: 7),

              Row(
                children: [
                  Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const Spacer(),

                  Expanded(
                    child: Text(
                      isOver
                          ? '${MoneyFormatter.format(difference.abs())} over budget'
                          : '${MoneyFormatter.format(difference)} remaining',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isOver
                            ? AppColors.expense
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _BudgetDetailsHero extends StatelessWidget {
  const _BudgetDetailsHero({
    required this.budget,
    required this.spent,
    required this.ratio,
    required this.color,
    required this.differenceAmount,
    required this.isOverBudget,
  });

  final Budget budget;
  final int spent;
  final double ratio;
  final Color color;
  final int differenceAmount;
  final bool isOverBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = ratio >= 1
        ? 'Over budget'
        : ratio >= budget.alertThreshold
        ? 'Near limit'
        : 'On track';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          _ProgressRing(
            value: ratio,
            color: color,
            main: '${(ratio * 100).round()}%',
            label: ratio >= 1 ? 'OVER BUDGET' : 'SPENT',
          ),

          const SizedBox(height: 18),

          Text(
            MoneyFormatter.format(spent),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'of ${MoneyFormatter.format(budget.amountMinor)} budget',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 14),

          _StatusPill(
            text: status,
            color: color,
            icon: ratio >= 1
                ? Icons.error_outline_rounded
                : ratio >= budget.alertThreshold
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOverBudget
                      ? Icons.trending_up_rounded
                      : Icons.account_balance_wallet_outlined,
                  size: 19,
                  color: color,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isOverBudget
                        ? '${MoneyFormatter.format(differenceAmount)} over budget'
                        : '${MoneyFormatter.format(differenceAmount)} remaining',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final String main;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.09),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                main,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final List<(String, String, IconData)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: _box(context),
      child: Column(
        children: rows.indexed.map((entry) {
          final (index, row) = entry;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(row.$3, color: AppColors.primary, size: 19),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        row.$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != rows.length - 1)
                Divider(height: 1, indent: 65, color: colors.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(context),
      child: Row(
        children: [
          _CategoryIcon(
            category: transaction.category,
            color: AppColors.expense,
            size: 44,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.category} • ${_date(transaction.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            MoneyFormatter.signed(transaction.amountMinor, negative: true),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.expense,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRelatedTransactions extends StatelessWidget {
  const _EmptyRelatedTransactions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: _box(context),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: colors.onSurfaceVariant,
              size: 25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No spending counted this period',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirmed category expenses within the active budget period will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        side: BorderSide(color: colors.outlineVariant),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.category,
    required this.color,
    this.size = 44,
  });

  final String category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size >= 40 ? 14 : 9),
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(category), size: size >= 40 ? 21 : 16, color: color),
    );
  }
}

BoxDecoration _box(BuildContext context) {
  final colors = Theme.of(context).colorScheme;

  return BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colors.outlineVariant),
  );
}

int _spent(Budget budget, List<Transaction> transactions) =>
    BudgetSpendingCalculator.spent(budget, transactions);

Color _progressColor(double ratio, double threshold) => ratio >= 1
    ? AppColors.expense
    : ratio >= threshold
    ? AppColors.warning
    : AppColors.primary;

String _capitalize(String text) {
  if (text.isEmpty) return text;

  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String _date(DateTime? date) {
  if (date == null) return 'Not set';

  return '${_month(date.month)} ${date.day}, ${date.year}';
}

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

  if (value.contains('food') ||
      value.contains('dining') ||
      value.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }

  if (value.contains('grocery') || value.contains('supermarket')) {
    return Icons.shopping_basket_rounded;
  }

  if (value.contains('transport') ||
      value.contains('fuel') ||
      value.contains('car')) {
    return Icons.directions_car_filled_rounded;
  }

  if (value.contains('entertain') || value.contains('movie')) {
    return Icons.movie_rounded;
  }

  if (value.contains('bill') || value.contains('utility')) {
    return Icons.receipt_long_rounded;
  }

  if (value.contains('health') || value.contains('medical')) {
    return Icons.medical_services_outlined;
  }

  if (value.contains('shopping')) {
    return Icons.shopping_bag_outlined;
  }

  if (value.contains('education')) {
    return Icons.school_outlined;
  }

  if (value.contains('home') || value.contains('rent')) {
    return Icons.home_outlined;
  }

  return Icons.pie_chart_rounded;
}
