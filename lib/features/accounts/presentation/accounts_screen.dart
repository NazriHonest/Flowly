import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/entities/account.dart';
import '../providers/account_provider.dart';
import 'add_account_screen.dart';
import 'account_details_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAccountScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: accounts.when(
        loading: () => const AppLoadingList(),
        error: (e, _) => AppErrorState(
          title: 'Couldn’t load accounts',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(accountListProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add an account to begin tracking your balances.',
                actionLabel: 'Add account',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Text(
                    'Your accounts',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...items.map((a) => _AccountTile(account: a)),
                ],
              ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});
  final Account account;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountDetailsScreen(account: account),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: Color(account.color),
        child: Icon(IconData(account.icon, fontFamily: 'MaterialIcons'), color: AppColors.onPrimary),
      ),
      title: Text(account.name),
      subtitle: Text(account.type.replaceAll('_', ' ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            MoneyFormatter.format(
              account.openingBalanceMinor,
              code: account.currency,
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    ),
  );
}
