import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/budget_history.dart';
import '../domain/services/budget_spending_calculator.dart';
import '../domain/services/budget_period_calculator.dart';
import '../providers/budget_provider.dart';
import '../providers/budget_history_provider.dart';
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

class BudgetDetailsScreen extends ConsumerStatefulWidget {
  const BudgetDetailsScreen({super.key, required this.budget});

  final Budget budget;

  @override
  ConsumerState<BudgetDetailsScreen> createState() =>
      _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends ConsumerState<BudgetDetailsScreen> {
  int selectedTab = 0;
  int historyPeriodCount = 6;

  @override
  Widget build(BuildContext context) {
    final current = widget.budget.id == null
        ? widget.budget
        : ref
                  .watch(budgetListProvider)
                  .valueOrNull
                  ?.where((item) => item.id == widget.budget.id)
                  .firstOrNull ??
              widget.budget;
    final transactions = ref.watch(transactionListProvider).value ?? [];
    final accounts = ref.watch(accountListProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryListProvider).valueOrNull ?? const [];

    final related = BudgetSpendingCalculator.countedTransactions(
      current,
      transactions,
    ).toList()..sort((a, b) => b.date.compareTo(a.date));

    final spent = BudgetSpendingCalculator.spent(current, transactions);

    final ratio = current.amountMinor == 0
        ? (spent == 0 ? 0.0 : double.infinity)
        : spent / current.amountMinor;

    final difference = current.amountMinor - spent;
    final bounds = BudgetPeriodCalculator.current(current);
    final category = categories
        .where((item) => item.name == current.category)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          PopupMenuButton<_BudgetDetailsAction>(
            tooltip: 'Budget options',
            onSelected: (action) => _handleAction(action, current),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _BudgetDetailsAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit budget'),
                ),
              ),
              PopupMenuItem(
                value: _BudgetDetailsAction.archive,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Archive budget'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        key: PageStorageKey('budget-details-${current.id}-$selectedTab'),
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          _DetailsIdentity(
            budget: current,
            categoryIcon: category?.icon,
            categoryColor: category?.color,
            bounds: bounds,
          ),
          const SizedBox(height: 18),
          _DetailsSummaryCard(
            budget: current,
            spent: spent,
            ratio: ratio,
            difference: difference,
          ),
          const SizedBox(height: 14),
          _DetailsIndicators(budget: current, ratio: ratio, bounds: bounds),
          const SizedBox(height: 18),
          BudgetDetailsSegmentedControl(
            selected: selectedTab,
            onChanged: (value) => setState(() => selectedTab = value),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: selectedTab == 0
                ? _DetailsOverview(
                    key: const ValueKey('overview'),
                    budget: current,
                    bounds: bounds,
                    transactions: related,
                    accounts: accounts,
                  )
                : _DetailsHistory(
                    key: const ValueKey('history'),
                    budget: current,
                    periodCount: historyPeriodCount,
                    onPeriodCountChanged: (value) =>
                        setState(() => historyPeriodCount = value),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(_BudgetDetailsAction action, Budget budget) async {
    if (action == _BudgetDetailsAction.edit) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: budget)),
      );
      return;
    }
    if (!await showFlowlyConfirmation(
      context,
      title: 'Archive budget?',
      message: 'This budget will be removed from active tracking.',
      confirmLabel: 'Archive budget',
    )) {
      return;
    }
    await ref.read(budgetListProvider.notifier).archive(budget.id!);
    if (mounted) Navigator.pop(context);
  }
}

enum _BudgetDetailsAction { edit, archive }

String _usd(int value) => MoneyFormatter.format(value, code: 'USD');

class _DetailsIdentity extends StatelessWidget {
  const _DetailsIdentity({
    required this.budget,
    required this.categoryIcon,
    required this.categoryColor,
    required this.bounds,
  });

  final Budget budget;
  final int? categoryIcon;
  final int? categoryColor;
  final BudgetPeriodBounds bounds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = categoryColor == null
        ? AppColors.primary
        : Color(categoryColor!);
    final dates = MaterialLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            categoryIcon == null
                ? Icons.savings_outlined
                // Persisted Material icon code points are intentionally dynamic.
                // ignore: non_const_argument_for_const_parameter
                : IconData(categoryIcon!, fontFamily: 'MaterialIcons'),
            color: accent,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                budget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${_capitalize(budget.period)} budget • '
                '${dates.formatMediumDate(bounds.start)} – '
                '${dates.formatMediumDate(bounds.end)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: budget.archived
                ? colors.surfaceContainerHighest
                : AppColors.income.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            budget.archived ? 'Archived' : 'Active',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: budget.archived
                  ? colors.onSurfaceVariant
                  : FlowlySemanticColors.of(context).incomeForeground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsSummaryCard extends StatelessWidget {
  const _DetailsSummaryCard({
    required this.budget,
    required this.spent,
    required this.ratio,
    required this.difference,
  });

  final Budget budget;
  final int spent;
  final double ratio;
  final int difference;

  @override
  Widget build(BuildContext context) {
    final color = _progressColor(ratio, budget.alertThreshold);
    final remainingLabel = difference < 0 ? 'Overspent' : 'Remaining';
    final percentage = ratio.isFinite ? '${(ratio * 100).round()}%' : '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DetailsMetric(
                    value: _usd(difference.abs()),
                    label: remainingLabel,
                    valueColor: difference < 0
                        ? FlowlySemanticColors.of(context).expenseForeground
                        : FlowlySemanticColors.of(context).incomeForeground,
                  ),
                ),
                _DetailsMetric(
                  value: percentage,
                  label: budget.amountMinor == 0 ? 'No limit' : 'Used',
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: ratio.isFinite ? ratio.clamp(0, 1) : 1,
                color: color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_usd(spent)} spent',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${_usd(budget.amountMinor)} budget',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsMetric extends StatelessWidget {
  const _DetailsMetric({
    required this.value,
    required this.label,
    this.alignEnd = false,
    this.valueColor,
  });

  final String value;
  final String label;
  final bool alignEnd;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900, color: valueColor),
      ),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _DetailsIndicators extends StatelessWidget {
  const _DetailsIndicators({
    required this.budget,
    required this.ratio,
    required this.bounds,
  });

  final Budget budget;
  final double ratio;
  final BudgetPeriodBounds bounds;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final days = bounds.end.difference(date).inDays;
    final status = ratio >= 1
        ? 'Over budget'
        : ratio >= budget.alertThreshold
        ? 'Warning'
        : 'On track';
    final statusDetail = ratio >= 1
        ? 'Limit exceeded'
        : ratio >= budget.alertThreshold
        ? 'Above ${(budget.alertThreshold * 100).round()}% alert'
        : 'Below ${(budget.alertThreshold * 100).round()}%';
    final color = _progressColor(ratio, budget.alertThreshold);
    return Row(
      children: [
        Expanded(
          child: _DetailsIndicator(
            icon: Icons.calendar_today_outlined,
            color: AppColors.primary,
            title: days < 0
                ? 'Ended'
                : days == 0
                ? 'Ends today'
                : '$days days',
            subtitle: days > 0 ? 'remaining' : 'current period',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailsIndicator(
            icon: ratio >= 1
                ? Icons.error_outline_rounded
                : ratio >= budget.alertThreshold
                ? Icons.warning_amber_rounded
                : Icons.notifications_none_rounded,
            color: color,
            title: status,
            subtitle: statusDetail,
          ),
        ),
      ],
    );
  }
}

class _DetailsIndicator extends StatelessWidget {
  const _DetailsIndicator({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class BudgetDetailsSegmentedControl extends StatelessWidget {
  const BudgetDetailsSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final item in const [(0, 'Overview'), (1, 'History')])
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == item.$1,
                child: InkWell(
                  key: ValueKey(
                    item.$1 == 0 ? 'budget-overview-tab' : 'budget-history-tab',
                  ),
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onChanged(item.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: BoxDecoration(
                      color: selected == item.$1
                          ? AppColors.primaryDark
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: selected == item.$1
                            ? Colors.white
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsOverview extends StatelessWidget {
  const _DetailsOverview({
    super.key,
    required this.budget,
    required this.bounds,
    required this.transactions,
    required this.accounts,
  });

  final Budget budget;
  final BudgetPeriodBounds bounds;
  final List<Transaction> transactions;
  final List<dynamic> accounts;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailsSectionCard(
          title: 'Budget details',
          children: [
            _DetailsRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Budget amount',
              value: _usd(budget.amountMinor),
            ),
            _DetailsRow(
              icon: Icons.calendar_month_outlined,
              label: 'Period',
              value: _capitalize(budget.period),
            ),
            _DetailsRow(
              icon: Icons.event_outlined,
              label: 'Start date',
              value: localizations.formatMediumDate(bounds.start),
            ),
            _DetailsRow(
              icon: Icons.event_available_outlined,
              label: 'End date',
              value: localizations.formatMediumDate(bounds.end),
            ),
            _DetailsRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: budget.category,
            ),
            _DetailsRow(
              icon: Icons.notifications_none_rounded,
              label: 'Alert threshold',
              value:
                  '${(budget.alertThreshold * 100).round()}% '
                  '(${_usd((budget.amountMinor * budget.alertThreshold).round())})',
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailsRecentExpenses(
          budget: budget,
          bounds: bounds,
          transactions: transactions,
          accounts: accounts,
        ),
      ],
    );
  }
}

class _DetailsSectionCard extends StatelessWidget {
  const _DetailsSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      if (!last) const Divider(height: 1),
    ],
  );
}

class _DetailsRecentExpenses extends StatelessWidget {
  const _DetailsRecentExpenses({
    required this.budget,
    required this.bounds,
    required this.transactions,
    required this.accounts,
  });

  final Budget budget;
  final BudgetPeriodBounds bounds;
  final List<Transaction> transactions;
  final List<dynamic> accounts;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent expenses',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionsScreen(
                      initialCategory: budget.category,
                      initialDateRange: DateTimeRange(
                        start: bounds.start,
                        end: bounds.end,
                      ),
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 24, 12, 28),
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses this period',
                message:
                    'Confirmed expenses in this category will appear here.',
              ),
            )
          else
            ...transactions
                .take(5)
                .map(
                  (transaction) => _BudgetExpenseRow(
                    transaction: transaction,
                    accountName: accounts
                        .where((account) => account.id == transaction.accountId)
                        .map((account) => account.name as String)
                        .firstOrNull,
                  ),
                ),
        ],
      ),
    ),
  );
}

class _BudgetExpenseRow extends StatelessWidget {
  const _BudgetExpenseRow({required this.transaction, this.accountName});

  final Transaction transaction;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(transaction.date);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailsScreen(transaction: transaction),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.expense,
                size: 21,
              ),
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date${accountName == null ? '' : ' • $accountName'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '-${_usd(transaction.amountMinor)}',
              style: TextStyle(
                color: FlowlySemanticColors.of(context).expenseForeground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DetailsHistory extends ConsumerWidget {
  const _DetailsHistory({
    super.key,
    required this.budget,
    required this.periodCount,
    required this.onPeriodCountChanged,
  });

  final Budget budget;
  final int periodCount;
  final ValueChanged<int> onPeriodCountChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (budget: budget, periodCount: periodCount);
    final history = ref.watch(budgetHistoryProvider(request));
    return history.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: AppErrorState(
          title: 'Couldn’t load budget history',
          message: 'Your current budget is still available.',
          onRetry: () => ref.invalidate(budgetHistoryProvider(request)),
        ),
      ),
      data: (value) {
        if (value.periods.isEmpty) {
          return const Card(
            child: AppEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No history yet',
              message: 'Budget history will appear as periods are recorded.',
            ),
          );
        }
        final previous = value.previous.reversed.toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Spending history',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: periodCount,
                            borderRadius: BorderRadius.circular(14),
                            items: const [3, 6, 12]
                                .map(
                                  (count) => DropdownMenuItem(
                                    value: count,
                                    child: Text('Last $count periods'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) onPeriodCountChanged(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _HistoryLegend(
                          color: AppColors.primary,
                          label: 'Spent',
                        ),
                        SizedBox(width: 16),
                        _HistoryLegend(label: 'Budget'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _BudgetHistoryChart(periods: value.periods),
                    ),
                    if (value.periods.any(
                      (period) => period.limitMinor == null,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Muted budget bars are omitted where a historical limit was not recorded.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous periods',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    if (previous.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No completed periods are available yet.',
                          ),
                        ),
                      )
                    else
                      ...previous.map(
                        (period) => _HistoryPeriodRow(
                          period: period,
                          threshold: budget.alertThreshold,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BudgetHistoryPeriodScreen(
                                budget: budget,
                                period: period,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryLegend extends StatelessWidget {
  const _HistoryLegend({this.color, required this.label});

  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.outlineVariant,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _BudgetHistoryChart extends StatelessWidget {
  const _BudgetHistoryChart({required this.periods});

  final List<BudgetHistoryPeriod> periods;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = periods.fold<int>(0, (value, period) {
      final periodMaximum = period.limitMinor == null
          ? period.spentMinor
          : period.spentMinor > period.limitMinor!
          ? period.spentMinor
          : period.limitMinor!;
      return periodMaximum > value ? periodMaximum : value;
    });
    final maxY = maximum <= 0 ? 10000.0 : maximum * 1.2;
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.outlineVariant.withValues(alpha: .55),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final period = periods[group.x];
              final label = rodIndex == 0 ? 'Spent' : 'Budget';
              final amount = rodIndex == 0
                  ? period.spentMinor
                  : period.limitMinor;
              if (amount == null) return null;
              return BarTooltipItem(
                '$label\n${_usd(amount)}',
                TextStyle(
                  color: colors.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '\$${(value / 100).round()}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= periods.length) {
                  return const SizedBox.shrink();
                }
                final label = periods[index].label;
                final compact = label.contains('–')
                    ? label.split('–').first.trim()
                    : label.split(' ').first;
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    compact,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < periods.length; index++)
            BarChartGroupData(
              x: index,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: periods[index].spentMinor.toDouble(),
                  width: periods.length > 8 ? 7 : 11,
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                if (periods[index].limitMinor != null)
                  BarChartRodData(
                    toY: periods[index].limitMinor!.toDouble(),
                    width: periods.length > 8 ? 7 : 11,
                    color: colors.outlineVariant,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _HistoryPeriodRow extends StatelessWidget {
  const _HistoryPeriodRow({
    required this.period,
    required this.threshold,
    required this.onTap,
  });

  final BudgetHistoryPeriod period;
  final double threshold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = period.ratio;
    final color = ratio == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : _progressColor(ratio, threshold);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        _usd(period.spentMinor),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        period.limitMinor == null
                            ? ' • Historical limit unavailable'
                            : ' / ${_usd(period.limitMinor!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        ratio == null
                            ? '—'
                            : ratio.isFinite
                            ? '${(ratio * 100).round()}%'
                            : '—',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: ratio == null
                          ? 0
                          : ratio.isFinite
                          ? ratio.clamp(0, 1)
                          : 1,
                      color: color,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class BudgetHistoryPeriodScreen extends StatelessWidget {
  const BudgetHistoryPeriodScreen({
    super.key,
    required this.budget,
    required this.period,
  });

  final Budget budget;
  final BudgetHistoryPeriod period;

  @override
  Widget build(BuildContext context) {
    final ratio = period.ratio;
    final difference = period.limitMinor == null
        ? null
        : period.limitMinor! - period.spentMinor;
    return Scaffold(
      appBar: AppBar(title: Text(period.label)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(period.start)} – '
                    '${MaterialLocalizations.of(context).formatMediumDate(period.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  _DetailsRow(
                    icon: Icons.payments_outlined,
                    label: 'Spent',
                    value: _usd(period.spentMinor),
                  ),
                  _DetailsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Budget limit',
                    value: period.limitMinor == null
                        ? 'Historical limit unavailable'
                        : _usd(period.limitMinor!),
                  ),
                  _DetailsRow(
                    icon: difference != null && difference < 0
                        ? Icons.trending_up_rounded
                        : Icons.savings_outlined,
                    label: difference != null && difference < 0
                        ? 'Overspent'
                        : 'Remaining',
                    value: difference == null ? '—' : _usd(difference.abs()),
                  ),
                  _DetailsRow(
                    icon: Icons.percent_rounded,
                    label: 'Used',
                    value: ratio == null || !ratio.isFinite
                        ? '—'
                        : '${(ratio * 100).round()}%',
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionsScreen(
                      initialCategory: period.category,
                      initialDateRange: DateTimeRange(
                        start: period.start,
                        end: period.end,
                      ),
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          if (period.transactions.isEmpty)
            const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No expenses',
              message: 'No confirmed expenses contributed to this period.',
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: period.transactions
                      .map(
                        (transaction) =>
                            _BudgetExpenseRow(transaction: transaction),
                      )
                      .toList(),
                ),
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

// Legacy private widgets retained temporarily for compatibility with pending
// downstream UI work; the redesigned details view no longer instantiates them.
// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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
