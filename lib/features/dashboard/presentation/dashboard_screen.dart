import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/domain/services/account_balance_calculator.dart';
import '../../accounts/providers/account_provider.dart';
import '../../accounts/presentation/balance_privacy.dart';
import '../../budgets/providers/budget_provider.dart';
import '../../budgets/domain/services/budget_spending_calculator.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/transaction_presentation.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';
import '../../transactions/providers/transaction_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionListProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];
    final budgets = ref.watch(budgetListProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const _DashboardHeader()),
      body: transactionState.when(
        loading: () => const AppLoadingList(count: 5),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load your overview',
          message: 'Please check your data and try again.',
          onRetry: () => ref.invalidate(transactionListProvider),
        ),
        data: (items) {
          final confirmed = items
              .where((item) => item.status == ReviewStatus.confirmed)
              .toList();

          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month);
          final nextMonthStart = DateTime(now.year, now.month + 1);

          final monthly = confirmed
              .where(
                (item) =>
                    !item.date.isBefore(monthStart) &&
                    item.date.isBefore(nextMonthStart),
              )
              .toList();

          final income = _sum(monthly, TransactionType.income);

          final expenses = _sum(monthly, TransactionType.expense);

          final balance = accounts.fold<int>(
            0,
            (total, account) =>
                total + AccountBalanceCalculator.current(account, items),
          );

          final categories = <String, int>{};

          for (final item in monthly.where(
            (item) => item.type == TransactionType.expense,
          )) {
            categories[item.category] =
                (categories[item.category] ?? 0) + item.amountMinor;
          }

          final topCategories = categories.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final reviewCount = items
              .where((item) => item.status == ReviewStatus.needsReview)
              .length;

          final totalBudgetLimit = budgets.fold<int>(
            0,
            (sum, budget) => sum + budget.amountMinor,
          );
          final totalBudgetSpent = budgets.fold<int>(
            0,
            (sum, budget) =>
                sum + BudgetSpendingCalculator.spent(budget, confirmed),
          );

          final recentTransactions =
              items
                  .where((item) => item.status != ReviewStatus.ignored)
                  .toList()
                ..sort(compareTransactionsByCreatedAtDescending);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              AppLayout.scrollContentGap,
            ),
            children: [
              _BalanceHero(
                balance: balance,
                income: income,
                expenses: expenses,
              ),

              if (reviewCount > 0) ...[
                const SizedBox(height: 16),
                _ReviewBanner(count: reviewCount),
              ],

              const SizedBox(height: 28),

              _OverallBudgetCard(
                spent: totalBudgetSpent,
                limit: totalBudgetLimit,
                budgetCount: budgets.length,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                ),
              ),

              const SizedBox(height: 20),

              _SectionHeader(
                title: 'Top spending',
                subtitle: topCategories.isEmpty
                    ? 'Your spending by category'
                    : 'This month',
              ),

              const SizedBox(height: 12),

              if (topCategories.isEmpty)
                const _InlineEmpty(
                  icon: Icons.donut_small_rounded,
                  title: 'No spending yet',
                  message: 'Your top spending categories will appear here.',
                )
              else
                _TopCategoriesPanel(
                  entries: topCategories.take(4).toList(),
                  total: expenses,
                ),

              const SizedBox(height: 28),

              _SectionHeader(
                title: 'Recent transactions',
                subtitle: recentTransactions.isEmpty ? null : 'Latest activity',
                action: recentTransactions.isEmpty ? null : 'See all',
                onAction: recentTransactions.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      ),
              ),

              const SizedBox(height: 10),

              if (recentTransactions.isEmpty)
                const _InlineEmpty(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  message: 'Add your first transaction to start tracking your finances.',
                )
              else
                Column(
                  children: recentTransactions
                      .take(5)
                      .map(
                        (item) => TransactionCard(
                          transaction: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailsScreen(transaction: item),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

int _sum(List<Transaction> transactions, TransactionType type) {
  return transactions
      .where((item) => item.type == type)
      .fold<int>(0, (sum, item) => sum + item.amountMinor);
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your financial overview',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.income,
    required this.expenses,
  });

  final int balance;
  final int income;
  final int expenses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.onPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total balance',
                      style: TextStyle(
                        color: AppColors.heroTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Across all accounts',
                      style: TextStyle(
                        color: AppColors.heroTextMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const BalanceVisibilityButton(
                foregroundColor: AppColors.onPrimary,
              ),
            ],
          ),

          const SizedBox(height: 18),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AccountBalanceText(
              amountMinor: balance,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'THIS MONTH',
            style: TextStyle(
              color: AppColors.heroTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 9),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.south_west_rounded,
                    label: 'Income',
                    value: income,
                    color: AppColors.heroIncome,
                  ),
                ),
                Container(width: 1, height: 42, color: AppColors.heroDivider),
                const SizedBox(width: 24),
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.north_east_rounded,
                    label: 'Expenses',
                    value: expenses,
                    color: AppColors.heroExpense,
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            MoneyFormatter.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.rule_rounded,
              color: AppColors.warning,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'transaction needs' : 'transactions need'} review',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Check uncertain automatic transactions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action!),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

class _OverallBudgetCard extends StatelessWidget {
  const _OverallBudgetCard({
    required this.spent,
    required this.limit,
    required this.budgetCount,
    required this.onViewAll,
  });

  final int spent;
  final int limit;
  final int budgetCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final semanticColors = FlowlySemanticColors.of(context);
    final progress = limit <= 0 ? 0.0 : spent / limit;
    final progressColor = progress >= 1
        ? semanticColors.expenseForeground
        : progress >= 0.8
        ? semanticColors.warningForeground
        : colors.primary;

    final percentage = limit <= 0 ? 0 : (progress * 100).round();

    final remaining = limit - spent;
    final overBudget = remaining < 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: progressColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Budget',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Aggregate of active budget periods',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percentage%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _BudgetSummaryMetric(
                  label: 'SPENT',
                  value: MoneyFormatter.format(spent),
                  color: progressColor,
                ),
              ),
              Expanded(
                child: _BudgetSummaryMetric(
                  label: 'LIMIT',
                  value: MoneyFormatter.format(limit),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: colors.surfaceContainerHighest,
              color: progressColor,
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Icon(
                overBudget
                    ? Icons.warning_amber_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 14,
                color: progressColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  overBudget
                      ? '${MoneyFormatter.format(remaining.abs())} over budget'
                      : '${MoneyFormatter.format(remaining)} remaining',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: overBudget ? progressColor : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$budgetCount active ${budgetCount == 1 ? 'budget' : 'budgets'}',
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all budgets'),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryMetric extends StatelessWidget {
  const _BudgetSummaryMetric({
    required this.label,
    required this.value,
    this.color,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _TopCategoriesPanel extends StatelessWidget {
  const _TopCategoriesPanel({required this.entries, required this.total});

  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _CategoryRow(
              name: entries[index].key,
              value: entries[index].value,
              total: total,
            ),
            if (index != entries.length - 1)
              Divider(
                height: 1,
                indent: 54,
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.value,
    required this.total,
  });

  final String name;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final progress = total == 0 ? 0.0 : value / total;

    final visual = _categoryVisual(name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(visual.icon, size: 20, color: visual.color),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      MoneyFormatter.format(value),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: visual.color,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${(progress * 100).round()}% of this month’s expenses',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
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

_CategoryVisual _categoryVisual(String category) {
  final normalized = category.trim().toLowerCase();

  if (normalized.contains('food') ||
      normalized.contains('dining') ||
      normalized.contains('restaurant')) {
    return const _CategoryVisual(Icons.restaurant_rounded, AppColors.warning);
  }

  if (normalized.contains('transport') ||
      normalized.contains('travel') ||
      normalized.contains('fuel')) {
    return const _CategoryVisual(
      Icons.directions_car_filled_rounded,
      AppColors.info,
    );
  }

  if (normalized.contains('bill') || normalized.contains('utilit')) {
    return const _CategoryVisual(Icons.receipt_long_rounded, AppColors.primary);
  }

  if (normalized.contains('shopping')) {
    return const _CategoryVisual(Icons.shopping_bag_rounded, AppColors.expense);
  }

  if (normalized.contains('health')) {
    return const _CategoryVisual(Icons.favorite_rounded, AppColors.expense);
  }

  return const _CategoryVisual(Icons.category_rounded, AppColors.secondary);
}

class _CategoryVisual {
  const _CategoryVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}
