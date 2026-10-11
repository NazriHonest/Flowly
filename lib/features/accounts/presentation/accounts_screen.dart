import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/account.dart';
import '../domain/services/account_balance_calculator.dart';
import '../providers/account_provider.dart';
import 'account_details_screen.dart';
import 'add_account_screen.dart';
import 'balance_privacy.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _openAddAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final accountState = ref.watch(accountListProvider);
    final transactionState = ref.watch(transactionListProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Accounts',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filled(
              tooltip: 'Add account',
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              onPressed: () => _openAddAccount(context),
            ),
          ),
        ],
      ),
      body: accountState.when(
        loading: () => const AppLoadingList(),
        error: (error, stackTrace) => AppErrorState(
          title: "Couldn't load accounts",
          message: 'Please try again.',
          onRetry: () => ref.invalidate(accountListProvider),
        ),
        data: (accounts) {
          return transactionState.when(
            loading: () => const AppLoadingList(),
            error: (error, stackTrace) => AppErrorState(
              title: "Couldn't load balances",
              message:
                  'Account balances could not be calculated. '
                  'Please try again.',
              onRetry: () => ref.invalidate(transactionListProvider),
            ),
            data: (transactions) {
              final accountBalances = <_AccountBalance>[];

              for (final account in accounts) {
                accountBalances.add(
                  _AccountBalance(
                    account: account,
                    balance: AccountBalanceCalculator.current(
                      account,
                      transactions,
                    ),
                  ),
                );
              }

              final totals = <String, int>{};

              for (final item in accountBalances) {
                final currency = item.account.currency;

                totals[currency] = (totals[currency] ?? 0) + item.balance;
              }

              final activeTypes = accounts
                  .map((account) => account.type)
                  .toSet();

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(accountListProvider.notifier).refresh();

                  await ref.read(transactionListProvider.notifier).refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    AppLayout.floatingActionGap,
                  ),
                  children: [
                    if (accounts.isEmpty)
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.65,
                        child: AppEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No accounts yet',
                          message:
                              'Add an account to begin tracking '
                              'your balances.',
                          actionLabel: 'Add account',
                          onAction: () => _openAddAccount(context),
                        ),
                      )
                    else ...[
                      _AccountsOverview(
                        totals: totals,
                        accountCount: accounts.length,
                        typeCount: activeTypes.length,
                      ),
                      const SizedBox(height: 24),
                      _SectionHeading(
                        title: 'Your accounts',
                        subtitle:
                            '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
                      ),
                      const SizedBox(height: 14),
                      ...accountBalances.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AccountCard(
                            account: item.account,
                            balance: item.balance,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AccountBalance {
  const _AccountBalance({required this.account, required this.balance});

  final Account account;
  final int balance;
}

// ------------------------------------------------------------
// Accounts overview
// ------------------------------------------------------------

class _AccountsOverview extends StatelessWidget {
  const _AccountsOverview({
    required this.totals,
    required this.accountCount,
    required this.typeCount,
  });

  final Map<String, int> totals;
  final int accountCount;
  final int typeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final sortedCurrencies = totals.keys.toList()..sort();

    return Container(
      width: double.infinity,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total balances',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const BalanceVisibilityButton(),
            ],
          ),
          const SizedBox(height: 18),

          // Different currencies are shown separately.
          // No implicit exchange-rate conversion.
          ...sortedCurrencies.map((currency) {
            final balance = totals[currency] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currency == 'USD'
                          ? 'US Dollar'
                          : currency == 'SOS'
                          ? 'Somali Shilling'
                          : currency,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: AccountBalanceText(
                      amountMinor: balance,
                      currencyCode: currency,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          Divider(height: 20, color: colors.outlineVariant),

          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  icon: Icons.wallet_outlined,
                  label: 'Accounts',
                  value: accountCount.toString(),
                ),
              ),
              Container(width: 1, height: 38, color: colors.outlineVariant),
              Expanded(
                child: _OverviewStat(
                  icon: Icons.category_outlined,
                  label: 'Types',
                  value: typeCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: colors.primary),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Section heading
// ------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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

// ------------------------------------------------------------
// Account card
// ------------------------------------------------------------

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.balance});

  final Account account;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final accent = Color(account.color);
    final accentForeground = AppColors.foregroundOn(accent);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountDetailsScreen(account: account),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      IconData(account.icon, fontFamily: 'MaterialIcons'),
                      color: accentForeground,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _typeLabel(account.type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AccountBalanceText(
                      amountMinor: balance,
                      currencyCode: account.currency,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      account.currency,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'cash':
      return 'Cash';
    case 'bank':
      return 'Bank';
    case 'mobile_money':
      return 'Mobile money';
    case 'credit':
      return 'Credit';
    default:
      return type.replaceAll('_', ' ');
  }
}
