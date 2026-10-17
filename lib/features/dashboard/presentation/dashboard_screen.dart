import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/domain/services/account_balance_calculator.dart';
import '../../accounts/providers/account_provider.dart';
import '../../accounts/presentation/balance_privacy.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/transaction_presentation.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../spending_allowance/presentation/spending_allowance_dashboard_card.dart';

/// Provide the existing navigation callbacks from the application's router/shell.
/// This avoids assuming route names or screen constructors not shown in this file.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenGoals,
    required this.onOpenRecurring,
    required this.onOpenCategories,
  });

  final VoidCallback onOpenGoals;
  final VoidCallback onOpenRecurring;
  final VoidCallback onOpenCategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionListProvider);
    final accounts = ref.watch(accountListProvider).value ?? [];

    void openBudgets() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()));

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
          final reviewCount = items
              .where((item) => item.status == ReviewStatus.needsReview)
              .length;
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
                const SizedBox(height: 14),
                _ReviewBanner(count: reviewCount),
              ],
              const SizedBox(height: 18),
              const SpendingAllowanceDashboardCard(),
              const SizedBox(height: 22),
              const _SectionHeader(title: 'Quick actions'),
              const SizedBox(height: 12),
              _QuickActionsRow(
                onBudgets: openBudgets,
                onGoals: onOpenGoals,
                onRecurring: onOpenRecurring,
                onCategories: onOpenCategories,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Recent transactions',
                subtitle: recentTransactions.isEmpty ? null : 'Latest activity',
                action: recentTransactions.isEmpty ? null : 'See all',
                onAction: recentTransactions.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
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
                            MaterialPageRoute<void>(
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

int _sum(List<Transaction> transactions, TransactionType type) => transactions
    .where((item) => item.type == type)
    .fold<int>(0, (sum, item) => sum + item.amountMinor);

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = colors.onPrimary;
    final muted = foreground.withValues(alpha: 0.78);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.86)],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: foreground,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Calculated balance',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              BalanceVisibilityButton(foregroundColor: foreground),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on recorded account activity',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AccountBalanceText(
              amountMinor: balance,
              style:
                  theme.textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ) ??
                  TextStyle(
                    color: foreground,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: foreground.withValues(alpha: 0.22)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Monthly income',
                  value: income,
                  icon: Icons.south_west_rounded,
                  foreground: foreground,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  label: 'Monthly expenses',
                  value: expenses,
                  icon: Icons.north_east_rounded,
                  foreground: foreground,
                  muted: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.foreground,
    required this.muted,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          MoneyFormatter.format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onBudgets,
    required this.onGoals,
    required this.onRecurring,
    required this.onCategories,
  });
  final VoidCallback onBudgets;
  final VoidCallback onGoals;
  final VoidCallback onRecurring;
  final VoidCallback onCategories;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FlowlySemanticColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            label: 'Budgets',
            icon: Icons.account_balance_wallet_outlined,
            accent: colors.primary,
            onTap: onBudgets,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            label: 'Goals',
            icon: Icons.flag_outlined,
            accent: semantic.infoForeground,
            onTap: onGoals,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            label: 'Recurring',
            icon: Icons.autorenew_rounded,
            accent: semantic.infoForeground,
            onTap: onRecurring,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            label: 'Categories',
            icon: Icons.category_outlined,
            accent: semantic.warningForeground,
            onTap: onCategories,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Open $label',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: accent, size: 23),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary, size: 21),
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
