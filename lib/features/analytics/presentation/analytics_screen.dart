import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../accounts/domain/entities/account.dart';
import '../../accounts/providers/account_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/presentation/transaction_details_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../transactions/providers/transaction_provider.dart';

enum AnalyticsRange {
  sevenDays,
  thirtyDays,
  thisMonth,
  lastMonth,
  threeMonths,
  sixMonths,
  thisYear,
  custom,
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsRange _range = AnalyticsRange.thisMonth;
  DateTimeRange? _custom;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionListProvider);
    final accounts = ref.watch(accountListProvider).value ?? const <Account>[];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Text(
          'Analytics',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Choose date range',
              onPressed: _pickRange,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 21),
            ),
          ),
        ],
      ),
      body: transactions.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Something went wrong',
          message: "We couldn't load your analytics.",
          onRetry: () => ref.invalidate(transactionListProvider),
        ),
        data: (items) {
          final dates = _custom ?? _rangeFor(_range, DateTime.now());
          final data = _Data.from(items, accounts, dates, _range);
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(transactionListProvider.notifier).refresh(),
                ref.read(accountListProvider.notifier).refresh(),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppLayout.scrollContentGap,
              ),
              children: [
                _RangeSelector(selected: _range, onSelected: _selectRange),
                const SizedBox(height: 18),
                _pad(_Summary(data: data)),
                const SizedBox(height: 22),
                _pad(
                  const _Header(
                    title: 'Spending activity',
                    subtitle: 'Daily spending over the selected period',
                  ),
                ),
                const SizedBox(height: 12),
                _pad(_ActivityChart(values: data.activity)),
                const SizedBox(height: 25),
                _pad(
                  _Categories(
                    values: data.categories,
                    total: data.expenses,
                    onOpen: (category) => _open(dates, category: category),
                  ),
                ),
                const SizedBox(height: 22),
                _pad(_Comparison(data: data)),
                const SizedBox(height: 12),
                _pad(_Insights(data: data)),
                const SizedBox(height: 24),
                _pad(
                  _Accounts(
                    values: data.accountValues,
                    total: data.expenses,
                    onOpen: (id) => _open(dates, accountId: id),
                  ),
                ),
                const SizedBox(height: 18),
                _pad(
                  _LargestExpenses(
                    values: data.largest,
                    onOpen: (item) => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TransactionDetailsScreen(transaction: item),
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

  Widget _pad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );
  void _selectRange(AnalyticsRange value) {
    if (value == AnalyticsRange.custom) {
      _pickRange();
      return;
    }
    setState(() {
      _range = value;
      _custom = null;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _rangeFor(_range, now),
    );
    if (picked != null && mounted) {
      setState(() {
        _range = AnalyticsRange.custom;
        _custom = picked;
      });
    }
  }

  void _open(DateTimeRange dates, {int? accountId, String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(
          initialAccountId: accountId,
          initialCategory: category,
          initialDateRange: dates,
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});
  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: AnalyticsRange.values.map((value) {
        final active = value == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                _rangeLabel(value),
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});
  final _Data data;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = FlowlySemanticColors.of(context);
    final neutral = data.change == null || data.change == 0;
    final down = data.change != null && data.change! < 0;
    final color = neutral
        ? scheme.onSurfaceVariant
        : down
        ? semantic.incomeForeground
        : semantic.expenseForeground;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: _panel(context, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total spending',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        MoneyFormatter.format(data.expenses),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      neutral
                          ? Icons.remove_rounded
                          : down
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                      color: color,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.change == null
                              ? 'New'
                              : '${data.change!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          data.labels.shortPrevious,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  'Income',
                  data.income,
                  semantic.incomeForeground,
                ),
              ),
              _Divider(scheme.outlineVariant),
              Expanded(
                child: _Metric(
                  'Expenses',
                  data.expenses,
                  semantic.expenseForeground,
                ),
              ),
              _Divider(scheme.outlineVariant),
              Expanded(
                child: _Metric(
                  'Net cash flow',
                  data.income - data.expenses,
                  data.income >= data.expenses
                      ? scheme.onSurface
                      : semantic.expenseForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            MoneyFormatter.format(value),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 42, color: color);
}

class _Header extends StatelessWidget {
  const _Header({
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      if (action != null)
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
          label: Text(action!),
        )
      else
        Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    ],
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.values});
  final List<_Bucket> values;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const _Empty(
        Icons.bar_chart_rounded,
        'No spending activity in this period.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final maximum = values.fold<int>(0, (a, b) => math.max(a, b.amount));
    final maxY = maximum <= 0 ? 100.0 : maximum * 1.25;
    final interval = maxY / 3;
    final step = math.max(1, (values.length / 5).ceil());
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: .55),
              dashArray: const [5, 4],
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
                reservedSize: 42,
                interval: interval,
                getTitlesWidget: (v, m) => Text(
                  _compact(v.round()),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 ||
                      i >= values.length ||
                      (i % step != 0 && i != values.length - 1)) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 7,
                    child: Text(
                      values[i].shortLabel,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${MoneyFormatter.format(values[group.x].amount)}\n',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: values[group.x].fullLabel,
                    style: TextStyle(
                      color: scheme.onInverseSurface.withValues(alpha: .7),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          barGroups: values
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.amount.toDouble(),
                      width: values.length > 40
                          ? 4
                          : values.length > 20
                          ? 7
                          : 11,
                      color: AppColors.primaryLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _Categories extends StatefulWidget {
  const _Categories({
    required this.values,
    required this.total,
    required this.onOpen,
  });
  final List<_Category> values;
  final int total;
  final ValueChanged<String> onOpen;
  @override
  State<_Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<_Categories> {
  bool expanded = false;
  int? selected;
  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const Column(
        children: [
          _Header(title: 'Spending by category'),
          SizedBox(height: 12),
          _Empty(
            Icons.donut_small_rounded,
            'No expense categories in this period.',
          ),
        ],
      );
    }
    final shown = expanded ? widget.values : _compactCategories(widget.values);
    return Column(
      children: [
        _Header(
          title: 'Spending by category',
          action: expanded ? 'Show less' : 'View all',
          onAction: () => setState(() {
            expanded = !expanded;
            selected = null;
          }),
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (context, size) {
            final donut = _Donut(
              values: shown,
              total: widget.total,
              selected: selected,
              onSelect: (v) => setState(() => selected = v),
            );
            final legend = _Legend(
              values: shown,
              total: widget.total,
              selected: selected,
              onSelect: (v) => setState(() => selected = v),
              onOpen: widget.onOpen,
              onRemaining: () => setState(() {
                expanded = true;
                selected = null;
              }),
            );
            if (size.maxWidth < 355) {
              return Column(
                children: [
                  SizedBox(height: 180, child: donut),
                  const SizedBox(height: 8),
                  legend,
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 166, height: 186, child: donut),
                const SizedBox(width: 13),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({
    required this.values,
    required this.total,
    required this.selected,
    required this.onSelect,
  });
  final List<_Category> values;
  final int total;
  final int? selected;
  final ValueChanged<int?> onSelect;
  @override
  Widget build(BuildContext context) {
    final active = selected == null ? null : values[selected!];
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 48,
            sectionsSpace: 0,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (event.isInterestedForInteractions &&
                    response?.touchedSection != null) {
                  final i = response!.touchedSection!.touchedSectionIndex;
                  if (i >= 0) onSelect(i);
                }
              },
            ),
            sections: values
                .asMap()
                .entries
                .map(
                  (e) => PieChartSectionData(
                    value: e.value.amount.toDouble(),
                    color: e.value.color,
                    showTitle: false,
                    radius: selected == e.key ? 27 : 22,
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  MoneyFormatter.format(active?.amount ?? total),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                active?.name ?? 'Total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.values,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onRemaining,
  });
  final List<_Category> values;
  final int total;
  final int? selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onOpen;
  final VoidCallback onRemaining;
  @override
  Widget build(BuildContext context) => Column(
    children: values.asMap().entries.map((e) {
      final v = e.value;
      final percentage = total == 0 ? 0 : v.amount / total * 100;
      return Material(
        color: selected == e.key
            ? v.color.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onSelect(e.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: v.color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    v.remaining
                        ? Icons.more_horiz_rounded
                        : _categoryIcon(v.name),
                    color: v.color,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${percentage.round()}%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 60,
                  child: Text(
                    MoneyFormatter.format(v.amount),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 23,
                  height: 23,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: v.remaining ? onRemaining : () => onOpen(v.name),
                    icon: Icon(
                      v.remaining
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.data});
  final _Data data;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negative = data.expenses < data.previous;
    final positive = data.expenses > data.previous;
    final color = !positive && !negative
        ? scheme.onSurfaceVariant
        : positive
        ? FlowlySemanticColors.of(context).incomeForeground
        : FlowlySemanticColors.of(context).expenseForeground;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _panel(context, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.labels.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _CompareValue(data.expenses, data.labels.current),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          negative
                              ? Icons.south_rounded
                              : data.change == 0
                              ? Icons.remove_rounded
                              : Icons.north_rounded,
                          color: color,
                          size: 15,
                        ),
                        Text(
                          data.change == null
                              ? 'New'
                              : '${data.change!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      data.labels.shortPrevious,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _CompareValue(
                  data.previous,
                  data.labels.previous,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareValue extends StatelessWidget {
  const _CompareValue(this.value, this.label, {this.alignEnd = false});
  final int value;
  final String label;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      FittedBox(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          MoneyFormatter.format(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      Text(
        label,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 9,
        ),
      ),
    ],
  );
}

class _Insights extends StatelessWidget {
  const _Insights({required this.data});
  final _Data data;
  @override
  Widget build(BuildContext context) {
    final highest = _Insight(
      Icons.north_rounded,
      AppColors.primary,
      'Highest spending day',
      data.highest == null
          ? 'No spending'
          : MoneyFormatter.format(data.highest!.amount),
      data.highest == null
          ? 'No expenses in this period'
          : DateFormat('MMM d, yyyy').format(data.highest!.date),
    );
    final category = _Insight(
      Icons.workspace_premium_rounded,
      AppColors.warning,
      'Top category',
      data.categories.isEmpty ? 'No category' : data.categories.first.name,
      data.categories.isEmpty || data.expenses == 0
          ? 'No expenses in this period'
          : '${(data.categories.first.amount / data.expenses * 100).round()}% of spending',
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: highest),
        const SizedBox(width: 10),
        Expanded(child: category),
      ],
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight(this.icon, this.color, this.title, this.value, this.detail);
  final IconData icon;
  final Color color;
  final String title, value, detail;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 84),
    padding: const EdgeInsets.all(9),
    decoration: _panel(context, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Accounts extends StatefulWidget {
  const _Accounts({
    required this.values,
    required this.total,
    required this.onOpen,
  });
  final List<_AccountValue> values;
  final int total;
  final ValueChanged<int> onOpen;
  @override
  State<_Accounts> createState() => _AccountsState();
}

class _AccountsState extends State<_Accounts> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final values = expanded ? widget.values : widget.values.take(3).toList();
    return Column(
      children: [
        _Header(
          title: 'Account spending',
          subtitle: 'Where your expenses were paid from',
          action: widget.values.length > 3
              ? expanded
                    ? 'Show less'
                    : 'View all'
              : null,
          onAction: () => setState(() => expanded = !expanded),
        ),
        const SizedBox(height: 9),
        if (values.isEmpty)
          const _Empty(
            Icons.account_balance_wallet_outlined,
            'No account spending in this period.',
          )
        else
          ...values.asMap().entries.map(
            (e) => _AccountRow(
              value: e.value,
              total: widget.total,
              color: _accountColors[e.key % _accountColors.length],
              onTap: () => widget.onOpen(e.value.id),
            ),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.value,
    required this.total,
    required this.color,
    required this.onTap,
  });
  final _AccountValue value;
  final int total;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : value.amount / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(value.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(share * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 72,
                        child: Text(
                          MoneyFormatter.format(value.amount),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: share.clamp(0.0, 1.0),
                      minHeight: 5,
                      color: color,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargestExpenses extends StatelessWidget {
  const _LargestExpenses({required this.values, required this.onOpen});
  final List<Transaction> values;
  final ValueChanged<Transaction> onOpen;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _panel(context, 16),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 15),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.receipt_long_outlined,
          color: AppColors.expense,
          size: 20,
        ),
      ),
      title: const Text(
        'Largest expenses',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        values.isEmpty
            ? 'No expenses in this period'
            : 'View the highest individual expenses',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
      children: values
          .take(5)
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              onTap: () => onOpen(item),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${item.category} • ${DateFormat('MMM d').format(item.date)}',
                style: const TextStyle(fontSize: 9),
              ),
              trailing: Text(
                MoneyFormatter.signed(item.amountMinor, negative: true),
                style: TextStyle(
                  color: FlowlySemanticColors.of(context).expenseForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.message);
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panel(context, 16),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Data {
  const _Data({
    required this.income,
    required this.expenses,
    required this.previous,
    required this.change,
    required this.activity,
    required this.categories,
    required this.accountValues,
    required this.largest,
    required this.highest,
    required this.labels,
  });
  final int income, expenses, previous;
  final double? change;
  final List<_Bucket> activity;
  final List<_Category> categories;
  final List<_AccountValue> accountValues;
  final List<Transaction> largest;
  final _Highest? highest;
  final _Labels labels;
  static _Data from(
    List<Transaction> all,
    List<Account> accounts,
    DateTimeRange range,
    AnalyticsRange selected,
  ) {
    final start = _day(range.start),
        end = _day(range.end),
        exclusive = end.add(const Duration(days: 1));
    final confirmed = all
        .where((t) => t.status == ReviewStatus.confirmed)
        .toList();
    final current = confirmed
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(exclusive))
        .toList();
    final expensesList = current
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final income = _sum(current, TransactionType.income),
        expenses = _sum(expensesList, TransactionType.expense);
    final previousRange = _previousRange(selected, start, end);
    final previous = _sum(
      confirmed.where(
        (t) =>
            t.type == TransactionType.expense &&
            !t.date.isBefore(previousRange.start) &&
            t.date.isBefore(previousRange.end.add(const Duration(days: 1))),
      ),
      TransactionType.expense,
    );
    final categories = <String, int>{},
        accountTotals = <int, int>{},
        daily = <DateTime, int>{};
    for (final t in expensesList) {
      final category = t.category.trim().isEmpty
          ? 'Uncategorized'
          : t.category.trim();
      categories[category] = (categories[category] ?? 0) + t.amountMinor;
      accountTotals[t.accountId] =
          (accountTotals[t.accountId] ?? 0) + t.amountMinor;
      final date = _day(t.date);
      daily[date] = (daily[date] ?? 0) + t.amountMinor;
    }
    final categoryEntries = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryValues = categoryEntries
        .asMap()
        .entries
        .map(
          (e) => _Category(
            e.value.key,
            e.value.value,
            _categoryColors[e.key % _categoryColors.length],
          ),
        )
        .toList();
    final byId = <int, Account>{
      for (final a in accounts)
        if (a.id != null) a.id!: a,
    };
    final accountEntries = accountTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final accountValues = accountEntries.map((e) {
      final a = byId[e.key];
      return _AccountValue(
        e.key,
        a?.name ?? 'Unknown account',
        e.value,
        _accountIcon(a?.type),
      );
    }).toList();
    final high = daily.entries.isEmpty
        ? null
        : daily.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final largest = expensesList.toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return _Data(
      income: income,
      expenses: expenses,
      previous: previous,
      change: _change(expenses, previous),
      activity: _activity(expensesList, start, end),
      categories: categoryValues,
      accountValues: accountValues,
      largest: largest,
      highest: high == null ? null : _Highest(high.key, high.value),
      labels: _labels(selected, range),
    );
  }
}

class _Bucket {
  const _Bucket(this.amount, this.shortLabel, this.fullLabel);
  final int amount;
  final String shortLabel, fullLabel;
}

class _Category {
  const _Category(this.name, this.amount, this.color, [this.remaining = false]);
  final String name;
  final int amount;
  final Color color;
  final bool remaining;
}

class _AccountValue {
  const _AccountValue(this.id, this.name, this.amount, this.icon);
  final int id, amount;
  final String name;
  final IconData icon;
}

class _Highest {
  const _Highest(this.date, this.amount);
  final DateTime date;
  final int amount;
}

class _Labels {
  const _Labels(this.title, this.current, this.previous, this.shortPrevious);
  final String title, current, previous, shortPrevious;
}

DateTimeRange _rangeFor(AnalyticsRange range, DateTime now) {
  final today = _day(now);
  return switch (range) {
    AnalyticsRange.sevenDays => DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    ),
    AnalyticsRange.thirtyDays => DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    ),
    AnalyticsRange.thisMonth => DateTimeRange(
      start: DateTime(today.year, today.month),
      end: today,
    ),
    AnalyticsRange.lastMonth => DateTimeRange(
      start: DateTime(today.year, today.month - 1),
      end: DateTime(today.year, today.month).subtract(const Duration(days: 1)),
    ),
    AnalyticsRange.threeMonths => DateTimeRange(
      start: DateTime(today.year, today.month - 2),
      end: today,
    ),
    AnalyticsRange.sixMonths => DateTimeRange(
      start: DateTime(today.year, today.month - 5),
      end: today,
    ),
    AnalyticsRange.thisYear => DateTimeRange(
      start: DateTime(today.year),
      end: today,
    ),
    AnalyticsRange.custom => DateTimeRange(start: today, end: today),
  };
}

DateTimeRange _previousRange(
  AnalyticsRange range,
  DateTime currentStart,
  DateTime currentEnd,
) {
  if (range == AnalyticsRange.thisMonth || range == AnalyticsRange.lastMonth) {
    return DateTimeRange(
      start: DateTime(currentStart.year, currentStart.month - 1),
      end: currentStart.subtract(const Duration(days: 1)),
    );
  }
  final days = currentEnd.difference(currentStart).inDays + 1;
  return DateTimeRange(
    start: currentStart.subtract(Duration(days: days)),
    end: currentStart.subtract(const Duration(days: 1)),
  );
}

List<_Bucket> _activity(List<Transaction> items, DateTime start, DateTime end) {
  final days = end.difference(start).inDays + 1,
      width = days <= 45
          ? 1
          : days <= 210
          ? 7
          : 30,
      count = (days / width).ceil();
  final values = List<int>.filled(count, 0);
  for (final item in items) {
    final offset = _day(item.date).difference(start).inDays;
    if (offset >= 0 && offset < days) {
      values[math.min(count - 1, offset ~/ width)] += item.amountMinor;
    }
  }
  return List.generate(count, (i) {
    final from = start.add(Duration(days: i * width)),
        proposed = from.add(Duration(days: width - 1)),
        to = proposed.isAfter(end) ? end : proposed;
    return _Bucket(
      values[i],
      DateFormat(days > 210 ? 'MMM' : 'MMM d').format(from),
      width == 1
          ? DateFormat('MMM d, yyyy').format(from)
          : '${DateFormat('MMM d').format(from)}–${DateFormat('MMM d').format(to)}',
    );
  });
}

List<_Category> _compactCategories(List<_Category> values) {
  if (values.length <= 5) return values;
  return [
    ...values.take(5),
    _Category(
      'Remaining categories',
      values.skip(5).fold(0, (sum, v) => sum + v.amount),
      const Color(0xFF94A3A0),
      true,
    ),
  ];
}

_Labels _labels(AnalyticsRange value, DateTimeRange dates) => switch (value) {
  AnalyticsRange.thisMonth => const _Labels(
    'Monthly comparison',
    'This month',
    'Last month',
    'vs last month',
  ),
  AnalyticsRange.lastMonth => const _Labels(
    'Monthly comparison',
    'Last month',
    'Previous month',
    'vs previous month',
  ),
  AnalyticsRange.sevenDays => const _Labels(
    '7-day comparison',
    'Last 7 days',
    'Previous 7 days',
    'vs previous 7 days',
  ),
  AnalyticsRange.thirtyDays => const _Labels(
    '30-day comparison',
    'Last 30 days',
    'Previous 30 days',
    'vs previous 30 days',
  ),
  AnalyticsRange.threeMonths => const _Labels(
    '3-month comparison',
    'Last 3 months',
    'Previous period',
    'vs previous period',
  ),
  AnalyticsRange.sixMonths => const _Labels(
    '6-month comparison',
    'Last 6 months',
    'Previous period',
    'vs previous period',
  ),
  AnalyticsRange.thisYear => const _Labels(
    'Yearly comparison',
    'This year',
    'Previous period',
    'vs previous period',
  ),
  AnalyticsRange.custom => _Labels(
    'Period comparison',
    '${DateFormat('MMM d').format(dates.start)}–${DateFormat('MMM d').format(dates.end)}',
    'Previous equal period',
    'vs previous period',
  ),
};
int _sum(Iterable<Transaction> items, TransactionType type) =>
    items.where((t) => t.type == type).fold(0, (sum, t) => sum + t.amountMinor);
double? _change(int current, int previous) => previous == 0
    ? current == 0
          ? 0
          : null
    : (current - previous) / previous * 100;
DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
String _rangeLabel(AnalyticsRange value) => switch (value) {
  AnalyticsRange.sevenDays => '7D',
  AnalyticsRange.thirtyDays => '30D',
  AnalyticsRange.thisMonth => 'This Month',
  AnalyticsRange.lastMonth => 'Last Month',
  AnalyticsRange.threeMonths => '3M',
  AnalyticsRange.sixMonths => '6M',
  AnalyticsRange.thisYear => '1Y',
  AnalyticsRange.custom => 'Custom',
};
String _compact(int minor) {
  final value = minor / 100, symbol = MoneyFormatter.symbolFor();
  if (value >= 1000000) {
    return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '$symbol${(value / 1000).toStringAsFixed(0)}K';
  }
  return '$symbol${value.toStringAsFixed(0)}';
}

IconData _categoryIcon(String name) {
  final v = name.toLowerCase();
  if (v.contains('bill') || v.contains('utilit')) {
    return Icons.receipt_long_rounded;
  }
  if (v.contains('food') || v.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }
  if (v.contains('transport') || v.contains('car')) {
    return Icons.directions_car_filled_rounded;
  }
  if (v.contains('subscription')) return Icons.autorenew_rounded;
  if (v.contains('shop')) return Icons.shopping_bag_rounded;
  if (v.contains('health')) return Icons.favorite_rounded;
  if (v.contains('rent') || v.contains('home')) return Icons.home_rounded;
  return Icons.category_rounded;
}

IconData _accountIcon(String? type) {
  return switch (type?.toLowerCase()) {
    'bank' => Icons.account_balance_rounded,
    'card' || 'credit' => Icons.credit_card_rounded,
    'mobile' || 'wallet' => Icons.account_balance_wallet_rounded,
    'cash' => Icons.payments_rounded,
    _ => Icons.account_balance_wallet_outlined,
  };
}

BoxDecoration _panel(BuildContext context, double radius) {
  final scheme = Theme.of(context).colorScheme,
      dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: scheme.outlineVariant.withValues(alpha: dark ? .38 : .70),
    ),
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: const Color(0xFF153D32).withValues(alpha: .035),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
  );
}

const _categoryColors = <Color>[
  Color(0xFF4568F2),
  Color(0xFFFF4264),
  Color(0xFFFF9800),
  Color(0xFF9342E8),
  Color(0xFF00B985),
  Color(0xFF94A3A0),
  Color(0xFF0284C7),
  Color(0xFFEC4899),
];
const _accountColors = <Color>[
  Color(0xFF08B981),
  Color(0xFF4088F4),
  Color(0xFF913BEA),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
];
