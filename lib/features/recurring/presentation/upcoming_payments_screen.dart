import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/presentation/category_visual.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../domain/entities/recurring_forecast.dart';
import '../providers/recurring_provider.dart';
import 'recurring_details_screen.dart';

enum _UpcomingFilter { all, expenses, income }

class UpcomingPaymentsScreen extends ConsumerStatefulWidget {
  const UpcomingPaymentsScreen({super.key});

  @override
  ConsumerState<UpcomingPaymentsScreen> createState() =>
      _UpcomingPaymentsScreenState();
}

class _UpcomingPaymentsScreenState
    extends ConsumerState<UpcomingPaymentsScreen> {
  _UpcomingFilter _filter = _UpcomingFilter.all;

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(upcomingRecurringOccurrencesProvider);
    final categories = ref.watch(recurringCategoriesProvider);
    final today =
        ref.watch(recurringTodayProvider).valueOrNull ?? DateTime.now();
    final filtered = occurrences
        .where((occurrence) {
          return switch (_filter) {
            _UpcomingFilter.all => true,
            _UpcomingFilter.expenses =>
              occurrence.schedule.type == TransactionType.expense,
            _UpcomingFilter.income =>
              occurrence.schedule.type == TransactionType.income,
          };
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Payments')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          AppLayout.safeScrollBottom(context),
        ),
        children: [
          _UpcomingFilters(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming payments',
              message: 'No matching recurring activity is due in 30 days.',
            )
          else
            ..._buildGroups(context, filtered, categories, today),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<RecurringOccurrence> occurrences,
    List<Category> categories,
    DateTime today,
  ) {
    final grouped = <String, List<RecurringOccurrence>>{};
    for (final occurrence in occurrences) {
      final label = _groupLabel(context, occurrence.date, today);
      grouped.putIfAbsent(label, () => []).add(occurrence);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 10));
      widgets.add(_GroupHeading(label: entry.key));
      widgets.add(const SizedBox(height: 7));
      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < entry.value.length; index++) ...[
                _UpcomingGroupedRow(
                  occurrence: entry.value[index],
                  categories: categories,
                  showDate: !entry.key.startsWith('Today'),
                ),
                if (index < entry.value.length - 1)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _UpcomingGroupedRow extends StatelessWidget {
  const _UpcomingGroupedRow({
    required this.occurrence,
    required this.categories,
    required this.showDate,
  });

  final RecurringOccurrence occurrence;
  final List<Category> categories;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final schedule = occurrence.schedule;
    return UpcomingOccurrenceCard(
      occurrence: occurrence,
      embedded: true,
      showDate: showDate,
      categoryVisual: resolveCategoryVisual(
        categories,
        schedule.category,
        fallbackColor: schedule.type == TransactionType.income
            ? AppColors.income
            : AppColors.expense,
        fallbackIcon: Icons.repeat_rounded,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecurringDetailsScreen(item: schedule),
        ),
      ),
    );
  }
}

class _UpcomingFilters extends StatelessWidget {
  const _UpcomingFilters({required this.selected, required this.onChanged});

  final _UpcomingFilter selected;
  final ValueChanged<_UpcomingFilter> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final value in _UpcomingFilter.values) ...[
        Expanded(
          child: _FilterButton(
            label: switch (value) {
              _UpcomingFilter.all => 'All',
              _UpcomingFilter.expenses => 'Expenses',
              _UpcomingFilter.income => 'Income',
            },
            selected: selected == value,
            onTap: () => onChanged(value),
          ),
        ),
        if (value != _UpcomingFilter.values.last) const SizedBox(width: 9),
      ],
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class UpcomingOccurrenceCard extends StatelessWidget {
  const UpcomingOccurrenceCard({
    super.key,
    required this.occurrence,
    required this.categoryVisual,
    required this.onTap,
    this.embedded = false,
    this.showDate = true,
  });

  final RecurringOccurrence occurrence;
  final CategoryVisual categoryVisual;
  final VoidCallback onTap;
  final bool embedded;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final schedule = occurrence.schedule;
    final income = schedule.type == TransactionType.income;
    final semantic = FlowlySemanticColors.of(context);
    final amountColor = income
        ? semantic.incomeForeground
        : semantic.expenseForeground;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(embedded ? 0 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(embedded ? 0 : 16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            border: embedded ? null : Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(embedded ? 0 : 16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: categoryVisual.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  categoryVisual.icon,
                  color: categoryVisual.color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_capitalize(schedule.frequency)} • '
                      '${income ? 'Income' : 'Expense'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (showDate) ...[
                      const SizedBox(height: 2),
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(occurrence.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    MoneyFormatter.signed(
                      schedule.amountMinor,
                      code: 'USD',
                      negative: !income,
                    ),
                    maxLines: 1,
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

String _groupLabel(BuildContext context, DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = day.difference(today).inDays;
  if (difference <= 0) {
    return 'Today • ${MaterialLocalizations.of(context).formatMediumDate(day)}';
  }
  if (difference == 1) return 'Tomorrow';
  if (difference <= 7) return 'This week';
  return 'Later';
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
