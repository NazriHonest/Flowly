import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../../core/formatters/money_formatter.dart';

import '../../../core/theme/app_colors.dart';

import '../../../core/widgets/app_widgets.dart';

import '../../accounts/providers/account_provider.dart';

import '../../transactions/domain/entities/transaction.dart';

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

  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',

          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      body: state.when(
        loading: () => const AppLoadingList(),

        error: (error, _) => AppErrorState(
          title: 'Something went wrong',

          message: 'We couldn’t load your analytics.',

          onRetry: () => ref.invalidate(transactionListProvider),
        ),

        data: (items) {
          final now = DateTime.now();

          final range = _customRange ?? _rangeFor(_range, now);

          final start = range.start;

          final end = range.end;

          final exclusiveEnd = DateTime(end.year, end.month, end.day + 1);

          final confirmed = items
              .where((item) => item.status == ReviewStatus.confirmed)
              .toList();

          final filtered = confirmed
              .where(
                (item) =>
                    !item.date.isBefore(start) &&
                    item.date.isBefore(exclusiveEnd),
              )
              .toList();

          final income = _sum(filtered, TransactionType.income);

          final expenses = _sum(filtered, TransactionType.expense);

          final netCashFlow = income - expenses;

          final savingsRate = income <= 0
              ? 0.0
              : ((income - expenses) / income) * 100;

          final days = end.difference(start).inDays + 1;

          final category = _group(
            filtered.where((item) => item.type == TransactionType.expense),

            (item) => item.category,
          );

          final merchant = _group(
            filtered.where((item) => item.type == TransactionType.expense),

            (item) => item.title,
          );

          final largestExpenses =
              filtered
                  .where((item) => item.type == TransactionType.expense)
                  .toList()
                ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

          final accounts = ref.watch(accountListProvider).value ?? [];

          final accountDistribution = _group(
            filtered.where((item) => item.type == TransactionType.expense),

            (item) => item.accountId.toString(),
          );

          final accountNames = {
            for (final account in accounts) '${account.id}': account.name,
          };

          final previousRange = DateTimeRange(
            start: start.subtract(Duration(days: days)),

            end: start.subtract(const Duration(days: 1)),
          );

          final previousExclusiveEnd = DateTime(
            previousRange.end.year,

            previousRange.end.month,

            previousRange.end.day + 1,
          );

          final previousExpenses = _sum(
            confirmed.where(
              (item) =>
                  item.type == TransactionType.expense &&
                  !item.date.isBefore(previousRange.start) &&
                  item.date.isBefore(previousExclusiveEnd),
            ),

            TransactionType.expense,
          );

          final expenseChange = _percentageChange(
            current: expenses,

            previous: previousExpenses,
          );

          final dailySpending = _dailyExpenseSeries(
            transactions: filtered,

            start: start,

            end: end,
          );

          final incomeExpenseTrend = _incomeExpenseSeries(
            transactions: filtered,

            start: start,

            end: end,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionListProvider);

              ref.invalidate(accountListProvider);
            },

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),

              children: [
                _RangeSelector(
                  selected: _range,

                  customRange: _customRange,

                  onSelected: (value) async {
                    if (value == AnalyticsRange.custom) {
                      final picked = await showDateRangePicker(
                        context: context,

                        firstDate: DateTime(2000),

                        lastDate: DateTime(now.year + 1, 12, 31),

                        initialDateRange:
                            _customRange ??
                            DateTimeRange(
                              start: DateTime(now.year, now.month, 1),

                              end: now,
                            ),
                      );

                      if (picked != null && mounted) {
                        setState(() {
                          _range = AnalyticsRange.custom;

                          _customRange = picked;
                        });
                      }

                      return;
                    }

                    setState(() {
                      _range = value;

                      _customRange = null;
                    });
                  },
                ),

                const SizedBox(height: 20),

                _OverviewCard(
                  income: income,

                  expenses: expenses,

                  netCashFlow: netCashFlow,

                  savingsRate: savingsRate,

                  rangeLabel: _rangeSummary(_range, range),
                ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Cash flow',

                  subtitle: 'Income and expenses over this period',
                ),

                const SizedBox(height: 10),

                _CashFlowChart(
                  series: incomeExpenseTrend,

                  income: income,

                  expenses: expenses,
                ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Spending trend',

                  subtitle: 'Your expense activity over time',
                ),

                const SizedBox(height: 10),

                _SpendingTrendCard(
                  values: dailySpending,

                  total: expenses,

                  days: days,
                ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Spending by category',

                  subtitle: 'Tap a category to view its transactions',
                ),

                const SizedBox(height: 10),

                if (category.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.donut_small_rounded,

                    message: 'No expense categories in this period.',
                  )
                else
                  _CategoryBreakdown(
                    values: category,

                    total: expenses,

                    onTap: (key) => _drillDown(
                      context,

                      TransactionsScreen(initialCategory: key),
                    ),
                  ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Account spending',

                  subtitle: 'Where your expenses were paid from',
                ),

                const SizedBox(height: 10),

                if (accountDistribution.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.account_balance_wallet_outlined,

                    message: 'No account spending in this period.',
                  )
                else
                  _BreakdownList(
                    values: accountDistribution,

                    labels: accountNames,

                    total: expenses,

                    icon: Icons.account_balance_wallet_outlined,

                    onTap: (key) {
                      final id = int.tryParse(key);

                      if (id != null) {
                        _drillDown(
                          context,

                          TransactionsScreen(initialAccountId: id),
                        );
                      }
                    },
                  ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Top merchants',

                  subtitle: 'Your highest spending destinations',
                ),

                const SizedBox(height: 10),

                if (merchant.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.storefront_outlined,

                    message: 'No merchant spending in this period.',
                  )
                else
                  _MerchantList(
                    values: merchant,

                    total: expenses,

                    onTap: (key) => _drillDown(
                      context,

                      TransactionsScreen(initialMerchant: key),
                    ),
                  ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Largest expenses',

                  subtitle: 'Highest individual expenses in this period',
                ),

                const SizedBox(height: 10),

                if (largestExpenses.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.receipt_long_outlined,

                    message: 'No expenses in this period.',
                  )
                else
                  _LargestExpensesList(
                    transactions: largestExpenses.take(5).toList(),
                  ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Period comparison',

                  subtitle: 'Compare spending with the previous period',
                ),

                const SizedBox(height: 10),

                _PeriodComparisonCard(
                  current: expenses,

                  previous: previousExpenses,

                  change: expenseChange,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

DateTimeRange _rangeFor(AnalyticsRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

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
      start: DateTime(now.year, now.month),

      end: today,
    ),

    AnalyticsRange.lastMonth => DateTimeRange(
      start: DateTime(now.year, now.month - 1),

      end: DateTime(now.year, now.month).subtract(const Duration(days: 1)),
    ),

    AnalyticsRange.threeMonths => DateTimeRange(
      start: DateTime(now.year, now.month - 2),

      end: today,
    ),

    AnalyticsRange.sixMonths => DateTimeRange(
      start: DateTime(now.year, now.month - 5),

      end: today,
    ),

    AnalyticsRange.thisYear => DateTimeRange(
      start: DateTime(now.year),

      end: today,
    ),

    AnalyticsRange.custom => DateTimeRange(start: today, end: today),
  };
}

String _label(AnalyticsRange range) => switch (range) {
  AnalyticsRange.sevenDays => '7 days',

  AnalyticsRange.thirtyDays => '30 days',

  AnalyticsRange.thisMonth => 'This month',

  AnalyticsRange.lastMonth => 'Last month',

  AnalyticsRange.threeMonths => '3 months',

  AnalyticsRange.sixMonths => '6 months',

  AnalyticsRange.thisYear => 'This year',

  AnalyticsRange.custom => 'Custom',
};

String _rangeSummary(AnalyticsRange range, DateTimeRange dateRange) {
  if (range != AnalyticsRange.custom) return _label(range);

  return '${_shortDate(dateRange.start)} – ${_shortDate(dateRange.end)}';
}

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

int _sum(Iterable<Transaction> items, TransactionType type) => items
    .where((item) => item.type == type)
    .fold<int>(0, (sum, item) => sum + item.amountMinor);

Map<String, int> _group(
  Iterable<Transaction> items,

  String Function(Transaction) key,
) {
  final values = <String, int>{};

  for (final item in items) {
    final normalized = key(item).trim();

    if (normalized.isEmpty) continue;

    values[normalized] = (values[normalized] ?? 0) + item.amountMinor;
  }

  return values;
}

double? _percentageChange({required int current, required int previous}) {
  if (previous == 0) return current == 0 ? 0 : null;

  return ((current - previous) / previous) * 100;
}

List<int> _dailyExpenseSeries({
  required List<Transaction> transactions,

  required DateTime start,

  required DateTime end,
}) {
  final days = end.difference(start).inDays + 1;

  final bucketCount = math.min(days, 14);

  final bucketSize = math.max(1, (days / bucketCount).ceil());

  final values = List<int>.filled(bucketCount, 0);

  for (final item in transactions) {
    if (item.type != TransactionType.expense) continue;

    final day = DateTime(item.date.year, item.date.month, item.date.day);

    final offset = day.difference(start).inDays;

    if (offset < 0) continue;

    final index = math.min(bucketCount - 1, offset ~/ bucketSize);

    values[index] += item.amountMinor;
  }

  return values;
}

_IncomeExpenseSeries _incomeExpenseSeries({
  required List<Transaction> transactions,

  required DateTime start,

  required DateTime end,
}) {
  final days = end.difference(start).inDays + 1;

  final bucketCount = math.min(days, 8);

  final bucketSize = math.max(1, (days / bucketCount).ceil());

  final income = List<int>.filled(bucketCount, 0);

  final expenses = List<int>.filled(bucketCount, 0);

  for (final item in transactions) {
    if (item.type != TransactionType.income &&
        item.type != TransactionType.expense) {
      continue;
    }

    final day = DateTime(item.date.year, item.date.month, item.date.day);

    final offset = day.difference(start).inDays;

    if (offset < 0) continue;

    final index = math.min(bucketCount - 1, offset ~/ bucketSize);

    if (item.type == TransactionType.income) {
      income[index] += item.amountMinor;
    } else {
      expenses[index] += item.amountMinor;
    }
  }

  return _IncomeExpenseSeries(income: income, expenses: expenses);
}

void _drillDown(BuildContext context, TransactionsScreen screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,

    required this.customRange,

    required this.onSelected,
  });

  final AnalyticsRange selected;

  final DateTimeRange? customRange;

  final ValueChanged<AnalyticsRange> onSelected;

  @override
  Widget build(BuildContext context) {
    const ranges = AnalyticsRange.values;

    return SizedBox(
      height: 38,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        itemCount: ranges.length,

        separatorBuilder: (_, __) => const SizedBox(width: 8),

        itemBuilder: (context, index) {
          final range = ranges[index];

          final isSelected = range == selected;

          final label =
              range == AnalyticsRange.custom &&
                  isSelected &&
                  customRange != null
              ? '${_shortDate(customRange!.start)} – ${_shortDate(customRange!.end)}'
              : _label(range);

          return _RangePill(
            label: label,

            selected: isSelected,

            onTap: () => onSelected(range),
          );
        },
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,

    required this.selected,

    required this.onTap,
  });

  final String label;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? AppColors.primary : colorScheme.surface,

      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : colorScheme.outlineVariant.withValues(alpha: .75),
        ),
      ),

      child: InkWell(
        customBorder: const StadiumBorder(),

        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),

          child: Text(
            label,

            style: TextStyle(
              color: selected ? AppColors.onPrimary : colorScheme.onSurface,

              fontSize: 12,

              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.income,

    required this.expenses,

    required this.netCashFlow,

    required this.savingsRate,

    required this.rangeLabel,
  });

  final int income;

  final int expenses;

  final int netCashFlow;

  final double savingsRate;

  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final positiveNet = netCashFlow >= 0;

    final savingsColor = savingsRate >= 0
        ? AppColors.income
        : AppColors.expense;

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
              const Text(
                'Financial overview',

                style: TextStyle(
                  color: AppColors.onPrimary,

                  fontSize: 16,

                  fontWeight: FontWeight.w800,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: .11),

                  borderRadius: BorderRadius.circular(999),
                ),

                child: Text(
                  rangeLabel,

                  style: const TextStyle(
                    color: AppColors.heroTextMuted,

                    fontSize: 10,

                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Net cash flow',

            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: .72),

              fontSize: 12,

              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            MoneyFormatter.signed(netCashFlow.abs(), negative: !positiveNet),

            style: const TextStyle(
              color: AppColors.onPrimary,

              fontSize: 30,

              height: 1.1,

              fontWeight: FontWeight.w800,

              letterSpacing: -.5,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.south_west_rounded,

                  label: 'Income',

                  value: MoneyFormatter.format(income),

                  color: AppColors.heroIncome,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _OverviewMetric(
                  icon: Icons.north_east_rounded,

                  label: 'Expenses',

                  value: MoneyFormatter.format(expenses),

                  color: AppColors.heroExpense,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _OverviewMetric(
                  icon: Icons.savings_outlined,

                  label: 'Savings',

                  value: '${savingsRate.round()}%',

                  color: savingsColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,

    required this.label,

    required this.value,

    required this.color,
  });

  final IconData icon;

  final String label;

  final String value;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),

      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: .09),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, size: 16, color: color),

          const SizedBox(height: 8),

          Text(
            label,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: .72),

              fontSize: 10,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            value,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: AppColors.onPrimary,

              fontSize: 12,

              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        if (subtitle != null) ...[
          const SizedBox(height: 2),

          Text(
            subtitle!,

            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({
    required this.series,
    required this.income,
    required this.expenses,
  });

  final _IncomeExpenseSeries series;
  final int income;
  final int expenses;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allValues = <int>[...series.income, ...series.expenses];
    final maxMinor = allValues.fold<int>(
      0,
      (current, value) => math.max(current, value),
    );
    final maxY = maxMinor <= 0 ? 1.0 : maxMinor.toDouble() * 1.15;
    final pointCount = math.max(series.income.length, series.expenses.length);
    final maxX = math.max(1, pointCount - 1).toDouble();

    final incomeSpots = List.generate(
      series.income.length,
      (index) => FlSpot(index.toDouble(), series.income[index].toDouble()),
    );
    final expenseSpots = List.generate(
      series.expenses.length,
      (index) => FlSpot(index.toDouble(), series.expenses[index].toDouble()),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendDot(
                color: AppColors.income,
                label: 'Income',
                value: MoneyFormatter.format(income),
              ),
              const SizedBox(width: 18),
              _LegendDot(
                color: AppColors.expense,
                label: 'Expenses',
                value: MoneyFormatter.format(expenses),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: .55),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (pointCount <= 1) return const SizedBox.shrink();
                        final index = value.round();
                        if (index < 0 || index >= pointCount) {
                          return const SizedBox.shrink();
                        }
                        final label = _chartPointLabel(index, pointCount);
                        if (label.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isIncome = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isIncome ? 'Income' : 'Expenses'}\n${MoneyFormatter.format(spot.y.round())}',
                        TextStyle(
                          color: isIncome
                              ? AppColors.income
                              : AppColors.expense,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: .3,
                    color: AppColors.income,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.income.withValues(alpha: .06),
                    ),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    curveSmoothness: .3,
                    color: AppColors.expense,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.expense.withValues(alpha: .05),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,

    required this.label,

    required this.value,
  });

  final Color color;

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 9,

            height: 9,

            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,

                    fontSize: 10,
                  ),
                ),

                Text(
                  value,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 12,

                    fontWeight: FontWeight.w800,
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

class _SpendingTrendCard extends StatelessWidget {
  const _SpendingTrendCard({
    required this.values,
    required this.total,
    required this.days,
  });

  final List<int> values;
  final int total;
  final int days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final average = days <= 0 ? 0 : total ~/ days;
    final maxMinor = values.fold<int>(
      0,
      (current, value) => math.max(current, value),
    );
    final maxY = maxMinor <= 0 ? 1.0 : maxMinor.toDouble() * 1.15;
    final maxX = math.max(1, values.length - 1).toDouble();
    final spots = List.generate(
      values.length,
      (index) => FlSpot(index.toDouble(), values[index].toDouble()),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  label: 'Total spent',
                  value: MoneyFormatter.format(total),
                ),
              ),
              Expanded(
                child: _SmallMetric(
                  label: 'Daily average',
                  value: MoneyFormatter.format(average),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: .55),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (values.length <= 1) return const SizedBox.shrink();
                        final index = value.round();
                        if (index < 0 || index >= values.length) {
                          return const SizedBox.shrink();
                        }
                        final label = _chartPointLabel(index, values.length);
                        if (label.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            MoneyFormatter.format(spot.y.round()),
                            const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: .3,
                    color: AppColors.secondary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.secondary.withValues(alpha: .20),
                          AppColors.secondary.withValues(alpha: .01),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
        ),

        const SizedBox(height: 2),

        Text(
          value,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.values,

    required this.total,

    required this.onTap,
  });

  final Map<String, int> values;

  final int total;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayEntries = _donutEntries(entries);

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: _panelDecoration(context),

      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 360;

          final donut = _CategoryDonutChart(
            entries: displayEntries,
            total: total,
          );

          final rows = Column(
            children: displayEntries.asMap().entries.map((pair) {
              final entry = pair.value;

              final percent = total == 0 ? 0.0 : entry.value / total;

              final color = _chartColors[pair.key % _chartColors.length];

              return _BreakdownRow(
                label: entry.key,

                value: entry.value,

                percent: percent,

                color: color,

                onTap: entry.key == 'Other' ? () {} : () => onTap(entry.key),
              );
            }).toList(),
          );

          if (stacked) {
            return Column(children: [donut, const SizedBox(height: 18), rows]);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              donut,

              const SizedBox(width: 18),

              Expanded(child: rows),
            ],
          );
        },
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({
    required this.values,

    required this.labels,

    required this.total,

    required this.icon,

    required this.onTap,
  });

  final Map<String, int> values;

  final Map<String, String> labels;

  final int total;

  final IconData icon;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),

      decoration: _panelDecoration(context),

      child: Column(
        children: entries.take(5).toList().asMap().entries.map((pair) {
          final entry = pair.value;

          final percent = total == 0 ? 0.0 : entry.value / total;

          final color = _chartColors[pair.key % _chartColors.length];

          return _BreakdownListTile(
            icon: icon,

            label: labels[entry.key] ?? entry.key,

            value: entry.value,

            percent: percent,

            color: color,

            onTap: () => onTap(entry.key),
          );
        }).toList(),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,

    required this.value,

    required this.percent,

    required this.color,

    required this.onTap,
  });

  final String label;

  final int value;

  final double percent;

  final Color color;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),

      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),

        child: Row(
          children: [
            Container(
              width: 9,

              height: 9,

              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                label,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 11,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  MoneyFormatter.format(value),

                  style: const TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.w800,
                  ),
                ),

                Text(
                  '${(percent * 100).round()}%',

                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,

                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownListTile extends StatelessWidget {
  const _BreakdownListTile({
    required this.icon,

    required this.label,

    required this.value,

    required this.percent,

    required this.color,

    required this.onTap,
  });

  final IconData icon;

  final String label;

  final int value;

  final double percent;

  final Color color;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),

      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),

        child: Row(
          children: [
            Container(
              width: 40,

              height: 40,

              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: color, size: 19),
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
                          label,

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

                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),

                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),

                      minHeight: 5,

                      color: color,

                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: 34,

              child: Text(
                '${(percent * 100).round()}%',

                textAlign: TextAlign.right,

                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,

                  fontSize: 10,

                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantList extends StatelessWidget {
  const _MerchantList({
    required this.values,

    required this.total,

    required this.onTap,
  });

  final Map<String, int> values;

  final int total;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),

      decoration: _panelDecoration(context),

      child: Column(
        children: entries.take(5).toList().asMap().entries.map((pair) {
          final entry = pair.value;

          final percent = total == 0 ? 0.0 : entry.value / total;

          return InkWell(
            borderRadius: BorderRadius.circular(12),

            onTap: () => onTap(entry.key),

            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),

              child: Row(
                children: [
                  Container(
                    width: 40,

                    height: 40,

                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .10),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Icon(
                      Icons.storefront_rounded,

                      color: AppColors.primary,

                      size: 19,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          entry.key,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 13,

                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '${(percent * 100).round()}% of spending',

                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,

                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Text(
                    MoneyFormatter.signed(entry.value, negative: true),

                    style: const TextStyle(
                      color: AppColors.expense,

                      fontSize: 12,

                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(width: 2),

                  Icon(
                    Icons.chevron_right_rounded,

                    color: colorScheme.onSurfaceVariant,

                    size: 18,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LargestExpensesList extends StatelessWidget {
  const _LargestExpensesList({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),

      decoration: _panelDecoration(context),

      child: Column(
        children: transactions.asMap().entries.map((pair) {
          final item = pair.value;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),

                child: Row(
                  children: [
                    Container(
                      width: 40,

                      height: 40,

                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: .10),

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons.north_east_rounded,

                        color: AppColors.expense,

                        size: 19,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            item.title,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              fontSize: 13,

                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            item.category,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,

                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      MoneyFormatter.signed(item.amountMinor, negative: true),

                      style: const TextStyle(
                        color: AppColors.expense,

                        fontSize: 12,

                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              if (pair.key != transactions.length - 1)
                Divider(
                  height: 1,

                  color: colorScheme.outlineVariant.withValues(alpha: .55),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PeriodComparisonCard extends StatelessWidget {
  const _PeriodComparisonCard({
    required this.current,

    required this.previous,

    required this.change,
  });

  final int current;

  final int previous;

  final double? change;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final spentLess = change != null && change! <= 0;

    final semanticColor = spentLess ? AppColors.income : AppColors.expense;

    String changeLabel;

    if (change == null) {
      changeLabel = 'No previous spending to compare';
    } else if (change == 0) {
      changeLabel = 'No change from previous period';
    } else {
      changeLabel =
          '${change!.abs().round()}% ${spentLess ? 'less' : 'more'} spending';
    }

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: _panelDecoration(context),

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ComparisonMetric(
                  label: 'Current period',

                  value: MoneyFormatter.format(current),

                  color: AppColors.expense,
                ),
              ),

              Container(
                width: 1,

                height: 42,

                color: colorScheme.outlineVariant,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _ComparisonMetric(
                  label: 'Previous period',

                  value: MoneyFormatter.format(previous),

                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),

            decoration: BoxDecoration(
              color: semanticColor.withValues(alpha: .09),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              children: [
                Icon(
                  spentLess
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,

                  color: semanticColor,

                  size: 18,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    changeLabel,

                    style: TextStyle(
                      color: semanticColor,

                      fontSize: 11,

                      fontWeight: FontWeight.w700,
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

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,

    required this.value,

    required this.color,
  });

  final String label;

  final String value;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
        ),

        const SizedBox(height: 3),

        Text(
          value,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: TextStyle(
            color: color,

            fontSize: 14,

            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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

      decoration: _panelDecoration(context),

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

BoxDecoration _panelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return BoxDecoration(
    color: colorScheme.surface,

    borderRadius: BorderRadius.circular(18),

    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: .65),
    ),
  );
}

const _chartColors = <Color>[
  AppColors.warning,

  AppColors.transfer,

  AppColors.secondary,

  AppColors.expense,

  AppColors.income,
];

class _IncomeExpenseSeries {
  const _IncomeExpenseSeries({required this.income, required this.expenses});

  final List<int> income;

  final List<int> expenses;
}

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({required this.entries, required this.total});

  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              centerSpaceRadius: 46,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(enabled: true),
              sections: entries.asMap().entries.map((pair) {
                final index = pair.key;
                final entry = pair.value;
                final percentage = total <= 0 ? 0.0 : entry.value / total * 100;

                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: _chartColors[index % _chartColors.length],
                  radius: 27,
                  showTitle: percentage >= 5,
                  title: '${percentage.round()}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  titlePositionPercentageOffset: .57,
                  borderSide: BorderSide.none,
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 86),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      MoneyFormatter.format(total),
                      maxLines: 1,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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

List<MapEntry<String, int>> _donutEntries(List<MapEntry<String, int>> entries) {
  if (entries.length <= _chartColors.length) return entries;

  final visibleCount = _chartColors.length - 1;
  final result = entries.take(visibleCount).toList();
  final otherTotal = entries
      .skip(visibleCount)
      .fold<int>(0, (sum, entry) => sum + entry.value);
  result.add(MapEntry('Other', otherTotal));
  return result;
}

String _chartPointLabel(int index, int count) {
  if (count <= 1) return '';
  if (index == 0) return 'Start';
  if (index == count - 1) return 'Now';
  if (index == (count - 1) ~/ 2) return 'Mid';
  return '';
}
