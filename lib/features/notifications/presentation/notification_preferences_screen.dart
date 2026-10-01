import 'package:flutter/material.dart';

import '../data/local_notification_service.dart';
import '../../../core/widgets/app_widgets.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final service = LocalNotificationService.instance;
  final keys = <String, String>{
    'budgetWarning': 'Budget warnings',
    'budgetExceeded': 'Budget exceeded',
    'needsReview': 'Needs Review',
    'recurring': 'Recurring transactions',
    'goals': 'Goals',
    'historicalImport': 'Historical import',
  };
  final enabled = <String, bool>{};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    for (final k in keys.keys) {
      enabled[k] = await service.enabled(k);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: enabled.length < keys.length
        ? const AppLoadingList(count: 4)
        : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            FlowlySection(title: 'Automatic tracking', children: [_preference('needsReview', Icons.rule_outlined, 'Needs review', 'When a transaction needs your confirmation'), _preference('historicalImport', Icons.download_for_offline_outlined, 'Historical import', 'When an import is ready to review')]),
            FlowlySection(title: 'Budgets', children: [_preference('budgetWarning', Icons.warning_amber_outlined, 'Budget warnings', 'When you are approaching a limit'), _preference('budgetExceeded', Icons.error_outline, 'Budget exceeded', 'When spending passes a budget limit')]),
            FlowlySection(title: 'Other', children: [_preference('recurring', Icons.repeat_rounded, 'Recurring transactions', 'When scheduled transactions are created'), _preference('goals', Icons.flag_outlined, 'Goal reached', 'When you reach a savings target')]),
          ]),
  );

  Widget _preference(String key, IconData icon, String title, String subtitle) => SwitchListTile.adaptive(secondary: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), value: enabled[key]!, onChanged: (value) async { await service.setEnabled(key, value); if (mounted) setState(() => enabled[key] = value); });
}
