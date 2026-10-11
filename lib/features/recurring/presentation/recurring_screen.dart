import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/presentation/category_visual.dart';
import '../domain/entities/recurring_forecast.dart';
import '../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';
import 'recurring_details_screen.dart';
import 'recurring_form_screen.dart';
import 'upcoming_payments_screen.dart';

enum _RecurringFilter { all, active, paused }

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  _RecurringFilter _filter = _RecurringFilter.all;
  final Set<String> _updatingItems = {};
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
    );
  }

  Future<void> _updateEnabled(RecurringTransaction item, bool enabled) async {
    final key = item.id?.toString() ?? item.title;

    if (_updatingItems.contains(key)) return;

    setState(() => _updatingItems.add(key));

    try {
      await ref
          .read(recurringListProvider.notifier)
          .setEnabled(item.id!, enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Recurring transaction resumed.'
                : 'Recurring transaction paused.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update recurring transaction.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingItems.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = ref.watch(recurringListProvider);
    final categories = ref.watch(recurringCategoriesProvider);
    final upcoming = ref.watch(upcomingRecurringOccurrencesProvider);
    final commitments = ref.watch(
      monthlyRecurringCommitmentsProvider(_selectedMonth),
    );
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Recurring Payments',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox.square(
              dimension: 52,
              child: IconButton.filled(
                tooltip: 'Add recurring transaction',
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 30),
                onPressed: _openAdd,
              ),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: "Couldn't load recurring transactions",
          message: 'Please try again.',
          onRetry: () => ref.invalidate(recurringListProvider),
        ),
        data: (items) {
          final activeCount = items.where((item) => item.enabled).length;
          final pausedCount = items.length - activeCount;

          final filtered = items.where((item) {
            switch (_filter) {
              case _RecurringFilter.all:
                return true;
              case _RecurringFilter.active:
                return item.enabled;
              case _RecurringFilter.paused:
                return !item.enabled;
            }
          }).toList();

          filtered.sort((a, b) {
            if (a.enabled != b.enabled) {
              return a.enabled ? -1 : 1;
            }

            return a.nextOccurrence.compareTo(b.nextOccurrence);
          });

          return RefreshIndicator(
            onRefresh: () => ref.read(recurringListProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                AppLayout.safeScrollBottom(context),
              ),
              children: [
                _RecurringOverview(
                  total: items.length,
                  active: activeCount,
                  paused: pausedCount,
                  month: _selectedMonth,
                  commitments: commitments,
                  onPreviousMonth: () => setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    ),
                  ),
                  onNextMonth: () => setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeadingAction(
                  title: 'Next upcoming',
                  actionLabel: 'View all',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UpcomingPaymentsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NextUpcomingPreview(
                  occurrence: upcoming.firstOrNull,
                  categories: categories,
                  onTap: upcoming.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecurringDetailsScreen(
                              item: upcoming.first.schedule,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 22),
                _SectionHeading(
                  title: 'Your recurring transactions',
                  subtitle: 'Manage scheduled income and expenses.',
                ),
                const SizedBox(height: 14),
                _RecurringFilters(
                  selected: _filter,
                  total: items.length,
                  active: activeCount,
                  paused: pausedCount,
                  onChanged: (filter) {
                    setState(() => _filter = filter);
                  },
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _RecurringEmptyState(onAdd: _openAdd)
                else if (filtered.isEmpty)
                  _FilteredEmptyState(filter: _filter)
                else
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < filtered.length;
                          index++
                        ) ...[
                          _RecurringCard(
                            item: filtered[index],
                            categoryVisual: resolveCategoryVisual(
                              categories,
                              filtered[index].category,
                              fallbackColor:
                                  filtered[index].type.name == 'income'
                                  ? AppColors.income
                                  : AppColors.expense,
                              fallbackIcon: Icons.repeat_rounded,
                            ),
                            updating: _updatingItems.contains(
                              filtered[index].id?.toString() ??
                                  filtered[index].title,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecurringDetailsScreen(
                                  item: filtered[index],
                                ),
                              ),
                            ),
                            onChanged: (enabled) =>
                                _updateEnabled(filtered[index], enabled),
                          ),
                          if (index < filtered.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colors.outlineVariant,
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Overview
// ------------------------------------------------------------

class _RecurringOverview extends StatelessWidget {
  const _RecurringOverview({
    required this.total,
    required this.active,
    required this.paused,
    required this.month,
    required this.commitments,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final int total;
  final int active;
  final int paused;
  final DateTime month;
  final MonthlyRecurringCommitments commitments;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = FlowlySemanticColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
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
                  color: colors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.autorenew_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monthly commitments',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 26),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '${_monthName(month.month)} ${month.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CommitmentMetric(
                  label: 'Scheduled expenses',
                  amount: commitments.scheduledExpensesMinor,
                  color: semantic.expenseForeground,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommitmentMetric(
                  label: 'Scheduled income',
                  amount: commitments.scheduledIncomeMinor,
                  color: semantic.incomeForeground,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CommitmentMetric(
                  label: 'Expected net',
                  amount: commitments.expectedNetMinor,
                  color: commitments.expectedNetMinor < 0
                      ? semantic.expenseForeground
                      : colors.onSurface,
                  icon: Icons.bar_chart_rounded,
                  signed: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  value: total.toString(),
                  label: 'Total',
                  icon: Icons.format_list_bulleted_rounded,
                  color: colors.primary,
                ),
              ),
              Container(width: 1, height: 38, color: colors.outlineVariant),
              Expanded(
                child: _OverviewStat(
                  value: active.toString(),
                  label: 'Active',
                  icon: Icons.play_arrow_rounded,
                  color: semantic.incomeForeground,
                ),
              ),
              Container(width: 1, height: 38, color: colors.outlineVariant),
              Expanded(
                child: _OverviewStat(
                  value: paused.toString(),
                  label: 'Paused',
                  icon: Icons.pause_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommitmentMetric extends StatelessWidget {
  const _CommitmentMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.signed = false,
  });

  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final bool signed;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 126),
    padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            signed
                ? MoneyFormatter.signed(
                    amount.abs(),
                    code: 'USD',
                    negative: amount < 0,
                  )
                : MoneyFormatter.format(amount, code: 'USD'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (signed)
                Icon(Icons.info_outline_rounded, size: 17, color: color),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NextUpcomingPreview extends StatelessWidget {
  const _NextUpcomingPreview({
    required this.occurrence,
    required this.categories,
    required this.onTap,
  });

  final RecurringOccurrence? occurrence;
  final List<Category> categories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = occurrence;
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_available_outlined),
            SizedBox(width: 12),
            Expanded(child: Text('No payments scheduled in the next 30 days.')),
          ],
        ),
      );
    }
    final schedule = value.schedule;
    return _UpcomingOccurrenceRow(
      occurrence: value,
      categoryVisual: resolveCategoryVisual(
        categories,
        schedule.category,
        fallbackColor: schedule.type.name == 'income'
            ? AppColors.income
            : AppColors.expense,
        fallbackIcon: Icons.repeat_rounded,
      ),
      onTap: onTap!,
    );
  }
}

// Kept as the grouped renderer used by widget-level timeline coverage.
// ignore: unused_element
class _UpcomingTimeline extends StatelessWidget {
  const _UpcomingTimeline({
    required this.occurrences,
    required this.categories,
    required this.today,
    required this.onTap,
  });

  final List<RecurringOccurrence> occurrences;
  final List<Category> categories;
  final DateTime today;
  final ValueChanged<RecurringOccurrence> onTap;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'No upcoming payments',
        message: 'No active recurring activity is due in the next 30 days.',
      );
    }

    final widgets = <Widget>[];
    String? previousGroup;
    for (final occurrence in occurrences) {
      final group = _timelineGroup(occurrence.date, today);
      if (group != previousGroup) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
        widgets.add(
          Text(
            group,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        previousGroup = group;
      }
      final schedule = occurrence.schedule;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _UpcomingOccurrenceRow(
            occurrence: occurrence,
            categoryVisual: resolveCategoryVisual(
              categories,
              schedule.category,
              fallbackColor: schedule.type.name == 'income'
                  ? AppColors.income
                  : AppColors.expense,
              fallbackIcon: Icons.repeat_rounded,
            ),
            onTap: () => onTap(occurrence),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _UpcomingOccurrenceRow extends StatelessWidget {
  const _UpcomingOccurrenceRow({
    required this.occurrence,
    required this.categoryVisual,
    required this.onTap,
  });

  final RecurringOccurrence occurrence;
  final CategoryVisual categoryVisual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final schedule = occurrence.schedule;
    final isIncome = schedule.type.name == 'income';
    final semantic = FlowlySemanticColors.of(context);
    final amountColor = isIncome
        ? semantic.incomeForeground
        : semantic.expenseForeground;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortMonth(occurrence.date.month).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${occurrence.date.day}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _shortWeekday(occurrence.date.weekday),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: categoryVisual.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryVisual.icon,
                  color: categoryVisual.color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${schedule.category}  •  '
                      '${_capitalize(schedule.frequency)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MoneyFormatter.signed(
                  schedule.amountMinor,
                  code: 'USD',
                  negative: !isIncome,
                ),
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Filters
// ------------------------------------------------------------

class _RecurringFilters extends StatelessWidget {
  const _RecurringFilters({
    required this.selected,
    required this.total,
    required this.active,
    required this.paused,
    required this.onChanged,
  });

  final _RecurringFilter selected;
  final int total;
  final int active;
  final int paused;
  final ValueChanged<_RecurringFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterChip(
            label: 'All',
            count: total,
            selected: selected == _RecurringFilter.all,
            onTap: () => onChanged(_RecurringFilter.all),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterChip(
            label: 'Active',
            count: active,
            selected: selected == _RecurringFilter.active,
            onTap: () => onChanged(_RecurringFilter.active),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterChip(
            label: 'Paused',
            count: paused,
            selected: selected == _RecurringFilter.paused,
            onTap: () => onChanged(_RecurringFilter.paused),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.10) : colors.surface,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                count.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Recurring transaction card
// ------------------------------------------------------------

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.categoryVisual,
    required this.updating,
    required this.onTap,
    required this.onChanged,
  });

  final RecurringTransaction item;
  final CategoryVisual categoryVisual;
  final bool updating;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = FlowlySemanticColors.of(context);

    final isIncome = item.type.name == 'income';
    final accent = isIncome
        ? semantic.incomeForeground
        : semantic.expenseForeground;
    final baseColor = categoryVisual.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      categoryVisual.icon,
                      color: categoryVisual.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.category,
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
                  Flexible(
                    child: Text(
                      MoneyFormatter.signed(
                        item.amountMinor,
                        code: 'USD',
                        negative: !isIncome,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _capitalize(item.frequency),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.event_outlined,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _shortDate(item.nextOccurrence),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (updating)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  else
                    Switch.adaptive(
                      value: item.enabled,
                      onChanged: onChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              if (!item.enabled) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      'Paused',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Section heading and empty states
// ------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeadingAction extends StatelessWidget {
  const _SectionHeadingAction({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      TextButton.icon(
        onPressed: onAction,
        label: Text(actionLabel),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _RecurringEmptyState extends StatelessWidget {
  const _RecurringEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.repeat_rounded,
      title: 'Nothing recurring yet',
      message:
          'Add a regular payment or income to keep your timeline accurate.',
      actionLabel: 'Add recurring',
      onAction: onAdd,
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.filter});

  final _RecurringFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isActive = filter == _RecurringFilter.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            isActive
                ? Icons.event_available_outlined
                : Icons.pause_circle_outline_rounded,
            size: 36,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            isActive ? 'No active transactions' : 'No paused transactions',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isActive
                ? 'Enable a recurring transaction to see it here.'
                : 'Paused recurring transactions will appear here.',
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

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

String _timelineGroup(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  final difference = day.difference(current).inDays;
  if (difference <= 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference <= 7) return 'This week';
  return 'Later';
}

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _shortDate(DateTime date) {
  const months = [
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
  ];

  return '${months[date.month - 1]} ${date.day}';
}

String _shortMonth(int month) => const [
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

String _shortWeekday(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _capitalize(String value) {
  if (value.isEmpty) return value;

  return '${value[0].toUpperCase()}${value.substring(1)}';
}
