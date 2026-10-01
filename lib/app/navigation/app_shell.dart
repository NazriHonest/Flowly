import 'package:flutter/material.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/categorization/presentation/learned_rules_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/recurring/presentation/recurring_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/providers/notification_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/information_screens.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/transaction_review/presentation/review_queue_screen.dart';
import '../../features/sms_detection/presentation/historical_import_screen.dart';
import '../../features/sms_detection/presentation/provider_management_screen.dart';
import '../../core/widgets/app_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final pages = const [
    DashboardScreen(),
    TransactionsScreen(),
    AnalyticsScreen(),
    AccountsScreen(),
    _MoreScreen(),
  ];
  final destinations = const [
    (Icons.home_outlined, 'Home'),
    (Icons.receipt_long_outlined, 'Transactions'),
    (Icons.pie_chart_outline, 'Analytics'),
    (Icons.account_balance_wallet_outlined, 'Accounts'),
    (Icons.more_horiz, 'More'),
  ];
  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.sizeOf(c).width >= 700;
    final content = pages[index];
    final rail = NavigationRail(
      selectedIndex: index,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: destinations
          .map(
            (d) =>
                NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
          )
          .toList(),
    );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(icon: Icon(d.$1), label: d.$2),
                  )
                  .toList(),
            ),
    );
  }
}

class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext c, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('More')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        FlowlySection(title: 'Planning', children: [
          _MoreRow(Icons.savings_outlined, 'Budgets', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const BudgetsScreen()))),
          _MoreRow(Icons.flag_outlined, 'Goals', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const GoalsScreen()))),
          _MoreRow(Icons.autorenew, 'Recurring', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RecurringScreen()))),
          _MoreRow(Icons.category_outlined, 'Categories', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
        ]),
        FlowlySection(title: 'Automatic tracking', children: [
          _MoreRow(Icons.rule_outlined, 'Needs review', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ReviewQueueScreen()))),
          _MoreRow(Icons.account_tree_outlined, 'SMS providers', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ProviderManagementScreen()))),
          _MoreRow(Icons.auto_awesome_outlined, 'Learned rules', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LearnedRulesScreen()))),
          _MoreRow(Icons.download_for_offline_outlined, 'Historical import', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const HistoricalImportScreen()))),
        ]),
        FlowlySection(title: 'Activity', children: [
          _MoreRow(Icons.notifications_outlined, 'Notifications', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NotificationsScreen())), trailing: ref.watch(unreadNotificationCountProvider) == 0 ? null : Badge(label: Text('${ref.watch(unreadNotificationCountProvider)}'))),
        ]),
        FlowlySection(title: 'Preferences', children: [
          _MoreRow(Icons.settings_outlined, 'Settings', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ]),
        FlowlySection(title: 'Support', children: [
          _MoreRow(Icons.help_outline, 'Help & support', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
          _MoreRow(Icons.privacy_tip_outlined, 'Privacy', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const PrivacyInformationScreen()))),
          _MoreRow(Icons.info_outline, 'About', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AboutScreen()))),
        ]),
        /*
        ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Supported providers'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const ProviderManagementScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_for_offline_outlined),
          title: const Text('Historical SMS import'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const HistoricalImportScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.savings_outlined),
          title: const Text('Budgets'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & support'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy information'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const PrivacyInformationScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Goals'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Categories'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.rule_outlined),
          title: const Text('Needs review'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const ReviewQueueScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.autorenew),
          title: const Text('Recurring transactions'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const RecurringScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Learned rules'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const LearnedRulesScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          trailing: ref.watch(unreadNotificationCountProvider) == 0
              ? null
              : Badge(
                  label: Text('${ref.watch(unreadNotificationCountProvider)}'),
                ),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      */],
    ),
  );
}

class _MoreRow extends StatelessWidget {
  const _MoreRow(this.icon, this.title, this.onTap, {this.trailing});
  final IconData icon; final String title; final VoidCallback onTap; final Widget? trailing;
  @override Widget build(BuildContext context) => ListTile(leading: CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .1), child: Icon(icon, size: 17)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: trailing ?? const Icon(Icons.chevron_right), onTap: onTap);
}
