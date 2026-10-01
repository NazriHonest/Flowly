import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';
import 'recurring_form_screen.dart';

class RecurringDetailsScreen extends ConsumerWidget {
  const RecurringDetailsScreen({super.key, required this.item});
  final RecurringTransaction item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = item.type.name == 'income';
    final color = income ? AppColors.income : AppColors.expense;
    return Scaffold(
      appBar: AppBar(title: Text(item.title), actions: [
        _Action(icon: Icons.edit_outlined, label: 'Edit recurring transaction', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringFormScreen(item: item)))),
        const SizedBox(width: 6),
        _Action(icon: Icons.archive_outlined, label: 'Archive recurring transaction', onTap: () async { if (!await showFlowlyConfirmation(context, title: 'Archive recurring transaction?', message: 'It will no longer be generated automatically.', confirmLabel: 'Archive')) return; await ref.read(recurringListProvider.notifier).archive(item.id!); if (context.mounted) Navigator.pop(context); }),
        const SizedBox(width: 16),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Center(child: Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Icon(income ? Icons.south_west_rounded : _icon(item.category), color: color, size: 23))),
        const SizedBox(height: 8),
        Center(child: Text(MoneyFormatter.signed(item.amountMinor, negative: !income), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800))),
        const SizedBox(height: 3),
        Center(child: _ActivePill(enabled: item.enabled)),
        const SizedBox(height: 18),
        _InfoTable(rows: [('Type', _capitalize(item.type.name)), ('Account', 'Checking account'), ('Category', item.category), ('Frequency', _capitalize(item.frequency)), ('Start date', _date(item.startDate)), ('End date', _date(item.endDate)), ('Next occurrence', _date(item.nextOccurrence)), ('Notes', item.notes.isEmpty ? 'None' : item.notes)]),
        const SizedBox(height: 16),
        Container(decoration: _box(context), child: SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12), title: const Text('Disable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), secondary: const Icon(Icons.timer_off_outlined, size: 17), value: item.enabled, onChanged: (enabled) => _save(ref, item, enabled))),
      ]),
    );
  }
}

class _InfoTable extends StatelessWidget { const _InfoTable({required this.rows}); final List<(String, String)> rows; @override Widget build(BuildContext context) => Container(decoration: _box(context), child: Column(children: rows.indexed.map((entry) { final (index, row) = entry; return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(border: index == 0 ? null : Border(top: BorderSide(color: AppColors.lightBorder.withValues(alpha: .7)))), child: Row(children: [Text(row.$1, style: Theme.of(context).textTheme.labelSmall), const Spacer(), Flexible(child: Text(row.$2, textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))])); }).toList())); }
class _ActivePill extends StatelessWidget { const _ActivePill({required this.enabled}); final bool enabled; @override Widget build(BuildContext context) { final color = enabled ? AppColors.income : AppColors.lightTextSecondary; return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)), child: Text(enabled ? '✓  Active' : 'Disabled', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color))); } }
class _Action extends StatelessWidget { const _Action({required this.icon, required this.label, required this.onTap}); final IconData icon; final String label; final VoidCallback onTap; @override Widget build(BuildContext context) => IconButton(tooltip: label, onPressed: onTap, icon: Icon(icon, size: 18), style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: const BorderSide(color: AppColors.lightBorder))); }
BoxDecoration _box(BuildContext context) => BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.lightBorder));
IconData _icon(String category) => category.toLowerCase().contains('entertain') ? Icons.play_arrow_rounded : category.toLowerCase().contains('rent') ? Icons.home_rounded : Icons.repeat_rounded;
String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
String _date(DateTime? value) => value == null ? 'None' : '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.day}, ${value.year}';
void _save(WidgetRef ref, RecurringTransaction item, bool enabled) => ref.read(recurringListProvider.notifier).save(RecurringTransaction(id: item.id, title: item.title, amountMinor: item.amountMinor, type: item.type, category: item.category, accountId: item.accountId, frequency: item.frequency, nextOccurrence: item.nextOccurrence, startDate: item.startDate, endDate: item.endDate, notes: item.notes, enabled: enabled));
