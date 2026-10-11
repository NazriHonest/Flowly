import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/presentation/widgets/transaction_card.dart';
import '../domain/entities/account.dart';
import '../domain/services/account_balance_calculator.dart';
import '../providers/account_provider.dart';
import 'add_account_screen.dart';
import 'balance_privacy.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final transactionsState = ref.watch(transactionListProvider);

    // Resolve the latest account when the provider updates, instead of
    // relying exclusively on the account snapshot passed by navigation.
    final accountState = ref.watch(accountListProvider);
    final currentAccount = accountState.maybeWhen(
      data: (accounts) {
        for (final item in accounts) {
          if (item.id == account.id) return item;
        }
        return account;
      },
      orElse: () => account,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          currentAccount.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        actions: [
          const BalanceVisibilityButton(),
          IconButton(
            tooltip: 'Edit account',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAccountScreen(account: currentAccount),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Archive account',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () async {
              final confirmed = await showFlowlyConfirmation(
                context,
                title: 'Archive account?',
                message:
                    'Archived accounts are hidden from new transactions '
                    'but remain in your history.',
                confirmLabel: 'Archive account',
              );

              if (!confirmed || !context.mounted) return;

              await ref
                  .read(accountListProvider.notifier)
                  .archive(currentAccount.id!);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsState.when(
        loading: () => const AppLoadingList(),
        error: (error, stackTrace) => AppErrorState(
          title: "Couldn't load account",
          message: 'Your transactions are still safe. Please try again.',
          onRetry: () => ref.invalidate(transactionListProvider),
        ),
        data: (allTransactions) {
          final accountTransactions = allTransactions.where((t) {
            final belongsToAccount =
                t.accountId == currentAccount.id ||
                (t.type == TransactionType.transfer &&
                    t.destinationAccountId == currentAccount.id);

            return belongsToAccount && t.status == ReviewStatus.confirmed;
          }).toList();

          final currentBalance = AccountBalanceCalculator.current(
            currentAccount,
            allTransactions,
          );

          final now = DateTime.now();
          final periodStart = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29));

          final datedTransactions = <_DatedTransaction>[];

          for (final transaction in accountTransactions) {
            final date = _AccountTransactionData.date(transaction);
            if (date != null) {
              datedTransactions.add(
                _DatedTransaction(transaction: transaction, date: date),
              );
            }
          }

          datedTransactions.sort((a, b) => b.date.compareTo(a.date));

          final recent = [...accountTransactions];
          recent.sort((a, b) {
            final aDate = _AccountTransactionData.date(a);
            final bDate = _AccountTransactionData.date(b);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          final periodTransactions = datedTransactions.where((item) {
            final date = item.date;
            return !date.isBefore(periodStart) && !date.isAfter(now);
          }).toList();

          var incomeMinor = 0;
          var expenseMinor = 0;

          for (final item in periodTransactions) {
            final delta = _AccountTransactionData.accountDelta(
              item.transaction,
              currentAccount.id.toString(),
            );

            if (delta == null) continue;

            if (item.transaction.type == TransactionType.income) {
              incomeMinor += math.max(0, delta);
            } else if (item.transaction.type == TransactionType.expense) {
              expenseMinor += math.max(0, -delta);
            }
          }

          final trend = _BalanceTrend.build(
            accountId: currentAccount.id.toString(),
            currentBalance: currentBalance,
            transactions: datedTransactions,
            periodStart: periodStart,
            now: now,
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _BalanceHero(account: currentAccount, balance: currentBalance),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Income',
                        value: MoneyFormatter.format(
                          incomeMinor,
                          code: currentAccount.currency,
                        ),
                        icon: Icons.south_west_rounded,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Expenses',
                        value: MoneyFormatter.format(
                          expenseMinor,
                          code: currentAccount.currency,
                        ),
                        icon: Icons.north_east_rounded,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BalanceChartCard(account: currentAccount, trend: trend),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AccountInformationCard(account: currentAccount),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${accountTransactions.length} total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyTransactions(),
                )
              else
                ...recent
                    .take(10)
                    .map(
                      (transaction) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TransactionCard(transaction: transaction),
                      ),
                    ),
              SizedBox(height: AppLayout.safeScrollBottom(context)),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.account, required this.balance});

  final Account account;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = Color(account.color);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconData(account.icon, fontFamily: 'MaterialIcons'),
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _accountTypeLabel(account.type),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  account.currency,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Current balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AccountBalanceText(
              amountMinor: balance,
              currencyCode: account.currency,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Available account balance',
                style: theme.textTheme.bodySmall?.copyWith(
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

class _BalanceChartCard extends ConsumerWidget {
  const _BalanceChartCard({required this.account, required this.trend});

  final Account account;
  final _BalanceTrend trend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance trend',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 30 days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          if (!ref.watch(balanceVisibilityProvider))
            Container(
              height: 190,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 32,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Balances hidden',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else if (!trend.available)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 34,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Balance history unavailable',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction dates or amounts could not be read.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 29,
                  minY: trend.minY,
                  maxY: trend.maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: trend.gridInterval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                      strokeWidth: 0.7,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
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
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if ((value - index).abs() > 0.001 ||
                              (index != 0 && index != 14 && index != 29)) {
                            return const SizedBox.shrink();
                          }

                          final day = trend.start.add(Duration(days: index));

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${day.day}/${day.month}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
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
                      getTooltipColor: (_) => colors.inverseSurface,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final day = trend.start.add(
                            Duration(days: spot.x.round()),
                          );
                          final amount = spot.y.round();

                          return LineTooltipItem(
                            '${day.day}/${day.month}\n'
                            '${MoneyFormatter.format(amount, code: account.currency)}',
                            TextStyle(
                              color: colors.onInverseSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trend.spots,
                      isCurved: false,
                      color: accent,
                      barWidth: 2.8,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withValues(alpha: 0.18),
                            accent.withValues(alpha: 0.015),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Daily closing balance',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '30 days',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Last 30 days',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInformationCard extends StatelessWidget {
  const _AccountInformationCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Account information',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Account type',
                value: _accountTypeLabel(account.type),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Currency',
                value: account.currency,
              ),
              Divider(height: 1, color: colors.outlineVariant),
              _InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Opening balance',
                trailing: AccountBalanceText(
                  amountMinor: account.openingBalanceMinor,
                  currencyCode: account.currency,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
  }) : assert(value != null || trailing != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Flexible(
            child:
                trailing ??
                Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Transactions for this account will appear here.',
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

String _accountTypeLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _DatedTransaction {
  const _DatedTransaction({required this.transaction, required this.date});

  final dynamic transaction;
  final DateTime date;
}

class _BalanceTrend {
  const _BalanceTrend({
    required this.start,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.gridInterval,
    required this.available,
  });

  final DateTime start;
  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final double gridInterval;
  final bool available;

  static _BalanceTrend build({
    required String? accountId,
    required int currentBalance,
    required List<_DatedTransaction> transactions,
    required DateTime periodStart,
    required DateTime now,
  }) {
    final start = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );

    // We reconstruct the historical balance by reversing confirmed
    // transactions from the known current balance.
    //
    // This requires the same transaction eligibility and balance
    // semantics as AccountBalanceCalculator.current.
    final dailyDeltas = List<int>.filled(30, 0);
    var totalDeltas = 0;
    var unreadableAmounts = false;

    for (final item in transactions) {
      if (item.date.isAfter(now)) continue;

      final delta = _AccountTransactionData.accountDelta(
        item.transaction,
        accountId,
      );

      if (delta == null) {
        unreadableAmounts = true;
        continue;
      }

      if (!item.date.isBefore(start)) {
        final day = DateTime(item.date.year, item.date.month, item.date.day);

        final index = day.difference(start).inDays;

        if (index >= 0 && index < dailyDeltas.length) {
          dailyDeltas[index] += delta;
          totalDeltas += delta;
        }
      }
    }

    if (unreadableAmounts) {
      return _BalanceTrend(
        start: start,
        spots: const [],
        minY: 0,
        maxY: 1,
        gridInterval: 1,
        available: false,
      );
    }

    var running = currentBalance - totalDeltas;
    final spots = <FlSpot>[];

    for (var i = 0; i < 30; i++) {
      running += dailyDeltas[i];
      spots.add(FlSpot(i.toDouble(), running.toDouble()));
    }

    final values = spots.map((spot) => spot.y).toList();
    final smallest = values.reduce(math.min);
    final largest = values.reduce(math.max);

    final span = largest - smallest;
    final padding = span == 0
        ? math.max(100.0, largest.abs() * 0.1)
        : span * 0.15;

    final minY = smallest - padding;
    final maxY = largest + padding;

    return _BalanceTrend(
      start: start,
      spots: spots,
      minY: minY,
      maxY: maxY,
      gridInterval: math.max(1.0, (maxY - minY) / 4),
      available: true,
    );
  }
}

/// Adapt this boundary to the canonical Transaction entity if its field
/// names differ. No database or repository changes are needed.
class _AccountTransactionData {
  static DateTime? date(dynamic transaction) {
    dynamic value;

    try {
      value = transaction.date;
    } catch (_) {
      try {
        value = transaction.transactionDate;
      } catch (_) {
        try {
          value = transaction.occurredAt;
        } catch (_) {
          try {
            value = transaction.createdAt;
          } catch (_) {
            return null;
          }
        }
      }
    }

    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.abs() < 100000000000 ? value * 1000 : value,
      );
    }

    return null;
  }

  static int? amountMinor(dynamic transaction) {
    dynamic value;

    try {
      value = transaction.amountMinor;
    } catch (_) {
      return null;
    }

    if (value is int) return value.abs();
    if (value is num) return value.abs().round();

    return null;
  }

  static int? accountDelta(dynamic transaction, String? accountId) {
    final amount = amountMinor(transaction);
    if (amount == null) return null;

    if (transaction.type == TransactionType.transfer) {
      final isSource = transaction.accountId == accountId;
      final isDestination = transaction.destinationAccountId == accountId;

      if (isSource && isDestination) return 0;
      if (isDestination) return amount;
      if (isSource) return -amount;
      return 0;
    }

    if (transaction.accountId != accountId) return 0;

    if (transaction.type == TransactionType.income) {
      return amount;
    }

    if (transaction.type == TransactionType.expense) {
      return -amount;
    }

    return 0;
  }
}
