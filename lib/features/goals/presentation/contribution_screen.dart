import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/entities/goal.dart';
import '../providers/goal_provider.dart';

class ContributionScreen extends ConsumerStatefulWidget {
  const ContributionScreen({super.key, required this.goal});
  final Goal goal;
  @override ConsumerState<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends ConsumerState<ContributionScreen> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  @override void dispose() { amount.dispose(); notes.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Add contribution')), body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Card(child: ListTile(leading: CircleAvatar(child: const Icon(Icons.savings_outlined)), title: Text(widget.goal.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: LinearProgressIndicator(value: widget.goal.progress.clamp(0, 1)), trailing: Text('${(widget.goal.progress * 100).round()}%'))),
    const SizedBox(height: 28), Center(child: Text('CONTRIBUTION AMOUNT', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))), TextField(controller: amount, textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.income, fontWeight: FontWeight.w800), decoration: const InputDecoration(prefixText: r'$ ', border: InputBorder.none)),
    const SizedBox(height: 20), ListTile(tileColor: Theme.of(context).inputDecorationTheme.fillColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), leading: const Icon(Icons.calendar_today_outlined), title: Text(MaterialLocalizations.of(context).formatMediumDate(date)), onTap: () async { final next = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (next != null) setState(() => date = next); }),
    const SizedBox(height: 14), TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional')),
    const Spacer(), FilledButton(onPressed: () async { final value = double.tryParse(amount.text); if (value == null || value <= 0) return; await ref.read(goalListProvider.notifier).contribute(widget.goal.id!, (value * 100).round()); if (mounted) Navigator.pop(context); }, child: const Text('Add Contribution')),
  ]))));
}
