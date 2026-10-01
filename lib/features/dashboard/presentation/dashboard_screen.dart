import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/providers/account_provider.dart';
import '../../budgets/providers/budget_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionListProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];
    final budgets = ref.watch(budgetListProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Here is your financial overview',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
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

          final income = _sum(confirmed, TransactionType.income);
          final expenses = _sum(confirmed, TransactionType.expense);

          final balance = accounts.fold<int>(
            0,
            (total, account) =>
                total +
                _accountBalance(
                  account.id,
                  account.openingBalanceMinor,
                  confirmed,
                ),
          );

          final categories = <String, int>{};
          for (final item in confirmed.where(
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _BalanceHero(
                balance: balance,
                income: income,
                expenses: expenses,
              ),
              const SizedBox(height: 24),

              if (reviewCount > 0) ...[
                _ReviewBanner(count: reviewCount),
                const SizedBox(height: 24),
              ],

              _SectionHeader(
                title: 'Budget progress',
                subtitle: budgets.isEmpty
                    ? null
                    : '${budgets.length} active ${budgets.length == 1 ? 'budget' : 'budgets'}',
              ),
              const SizedBox(height: 10),
              if (budgets.isEmpty)
                const _InlineEmpty(
                  icon: Icons.account_balance_wallet_outlined,
                  message: 'Create a budget to keep spending on track.',
                )
              else
                ...budgets.take(3).map((budget) {
                  final spent = confirmed
                      .where(
                        (item) =>
                            item.type == TransactionType.expense &&
                            item.category == budget.category,
                      )
                      .fold<int>(0, (sum, item) => sum + item.amountMinor);

                  final progress = budget.amountMinor == 0
                      ? 0.0
                      : spent / budget.amountMinor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BudgetProgressTile(
                      name: budget.name,
                      spent: spent,
                      total: budget.amountMinor,
                      progress: progress,
                    ),
                  );
                }),

              const SizedBox(height: 14),
              _SectionHeader(
                title: 'Top categories',
                subtitle: topCategories.isEmpty
                    ? null
                    : 'Where your money is going',
              ),
              const SizedBox(height: 10),
              if (topCategories.isEmpty)
                const _InlineEmpty(
                  icon: Icons.donut_small_rounded,
                  message: 'Your category breakdown will appear here.',
                )
              else
                _TopCategoriesPanel(
                  entries: topCategories.take(4).toList(),
                  total: expenses,
                ),

              const SizedBox(height: 24),

              // Keep the Recent Transactions section intentionally simple.
              // It uses the same shared TransactionCard as TransactionsScreen.
              _SectionHeader(
                title: 'Recent transactions',
                action: 'See all',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                ),
              ),
              const SizedBox(height: 4),
              if (items.isEmpty)
                const _InlineEmpty(
                  icon: Icons.receipt_long_outlined,
                  message: 'No transactions yet. Add your first transaction to start tracking.',
                )
              else
                Column(
                  children: items
                      .where((item) => item.status != ReviewStatus.ignored)
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

int _accountBalance(
  int? id,
  int openingBalance,
  List<Transaction> transactions,
) {
  final income = transactions
      .where(
        (item) => item.accountId == id && item.type == TransactionType.income,
      )
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  final expenses = transactions
      .where(
        (item) => item.accountId == id && item.type == TransactionType.expense,
      )
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  final outgoing = transactions
      .where(
        (item) => item.accountId == id && item.type == TransactionType.transfer,
      )
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  final incoming = transactions
      .where(
        (item) =>
            item.destinationAccountId == id &&
            item.type == TransactionType.transfer,
      )
      .fold<int>(0, (sum, item) => sum + item.amountMinor);

  return openingBalance + income - expenses - outgoing + incoming;
}

int _sum(List<Transaction> transactions, TransactionType type) => transactions
    .where((item) => item.type == type)
    .fold<int>(0, (sum, item) => sum + item.amountMinor);

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
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .18),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Total balance',
                  style: TextStyle(
                    color: AppColors.heroTextMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                color: AppColors.onPrimary.withValues(alpha: .72),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            MoneyFormatter.format(balance),
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.south_west_rounded,
                    label: 'Income',
                    value: income,
                    color: AppColors.heroIncome,
                  ),
                ),
                Container(width: 1, height: 38, color: AppColors.heroDivider),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rule_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'transaction needs' : 'transactions need'} review',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check uncertain automatic transactions.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _BudgetProgressTile extends StatelessWidget {
  const _BudgetProgressTile({
    required this.name,
    required this.spent,
    required this.total,
    required this.progress,
  });

  final String name;
  final int spent;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final exceeded = progress >= 1;
    final progressColor = exceeded ? AppColors.expense : AppColors.primary;
    final percentage = (progress * 100).clamp(0, 999).round();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: .65),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.savings_outlined,
                  color: progressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${MoneyFormatter.format(spent)} of ${MoneyFormatter.format(total)}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCategoriesPanel extends StatelessWidget {
  const _TopCategoriesPanel({required this.entries, required this.total});

  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: .65),
        ),
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
                color: colorScheme.outlineVariant.withValues(alpha: .55),
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
    final colorScheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : value / total;
    final visual = _categoryVisual(name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: .12),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormatter.format(value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: visual.color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(progress * 100).round()}% of expenses',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
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
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: .65),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.35),
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
