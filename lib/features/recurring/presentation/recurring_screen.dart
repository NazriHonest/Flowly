import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';
import 'recurring_details_screen.dart';
import 'recurring_form_screen.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recurringListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring'), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: IconButton.filled(style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), icon: const Icon(Icons.add, size: 19), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringFormScreen()))))]),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(title: 'Couldn’t load recurring transactions', message: 'Please try again.', onRetry: () => ref.invalidate(recurringListProvider)),
        data: (items) => items.isEmpty
            ? AppEmptyState(icon: Icons.repeat_rounded, title: 'Nothing recurring yet', message: 'Add a regular payment or income to keep your timeline accurate.', actionLabel: 'Add recurring', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringFormScreen())))
            : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, index) => _RecurringCard(item: items[index], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringDetailsScreen(item: items[index]))), onChanged: (enabled) => _saveEnabled(ref, items[index], enabled))),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.item, required this.onTap, required this.onChanged});
  final RecurringTransaction item;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final income = item.type.name == 'income';
    final color = income ? AppColors.income : AppColors.expense;
    return Material(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(9), child: InkWell(borderRadius: BorderRadius.circular(9), onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: _recurringBox(context), child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(7)), child: Icon(income ? Icons.south_west_rounded : _recurringIcon(item.category), color: color, size: 15)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), Text('${_capitalize(item.frequency)} · Next ${_shortDate(item.nextOccurrence)}', style: Theme.of(context).textTheme.labelSmall)])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(MoneyFormatter.signed(item.amountMinor, negative: !income), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)), SizedBox(height: 20, child: Transform.scale(scale: .72, child: Switch(value: item.enabled, onChanged: onChanged)))]),
    ]))));
  }
}

BoxDecoration _recurringBox(BuildContext context) => BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.lightBorder));
IconData _recurringIcon(String category) { final v = category.toLowerCase(); if (v.contains('entertain')) return Icons.play_arrow_rounded; if (v.contains('rent') || v.contains('home')) return Icons.home_rounded; if (v.contains('internet')) return Icons.bolt_rounded; return Icons.repeat_rounded; }
String _shortDate(DateTime date) => '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.day}';
String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
void _saveEnabled(WidgetRef ref, RecurringTransaction item, bool enabled) => ref.read(recurringListProvider.notifier).save(RecurringTransaction(id: item.id, title: item.title, amountMinor: item.amountMinor, type: item.type, category: item.category, accountId: item.accountId, frequency: item.frequency, nextOccurrence: item.nextOccurrence, endDate: item.endDate, startDate: item.startDate, notes: item.notes, enabled: enabled));
