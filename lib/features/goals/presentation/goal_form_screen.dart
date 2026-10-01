import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/entities/goal.dart';
import '../providers/goal_provider.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goal});
  final Goal? goal;
  @override ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.goal?.name ?? '');
  late final target = TextEditingController(text: widget.goal == null ? '' : (widget.goal!.targetMinor / 100).toStringAsFixed(2));
  late final starting = TextEditingController(text: widget.goal == null ? '' : (widget.goal!.currentMinor / 100).toStringAsFixed(2));
  DateTime? targetDate;
  int selectedIcon = Icons.savings_outlined.codePoint;
  int selectedColor = AppColors.primary.toARGB32();
  static const _icons = [Icons.savings_outlined, Icons.home_outlined, Icons.flight_takeoff_outlined, Icons.card_giftcard_outlined, Icons.favorite_border, Icons.flag_outlined, Icons.school_outlined, Icons.directions_car_outlined];
  @override void initState() { super.initState(); targetDate = widget.goal?.targetDate; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.goal == null ? 'Add goal' : 'Edit goal')), body: Form(key: form, child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    Text('Goal name', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 6), TextFormField(controller: name, decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined)), validator: (value) => (value ?? '').isEmpty ? 'Enter a name' : null),
    const SizedBox(height: 18), Text('Target amount', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 6), TextFormField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixIcon: Icon(Icons.payments_outlined), prefixText: r'$ '), validator: (value) => double.tryParse(value ?? '') == null ? 'Enter an amount' : null),
    const SizedBox(height: 18), Text('Starting amount', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 6), TextFormField(controller: starting, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_wallet_outlined), prefixText: r'$ '), validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid amount' : null),
    const SizedBox(height: 18), Text('Target date', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 6), ListTile(tileColor: Theme.of(context).inputDecorationTheme.fillColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), contentPadding: EdgeInsets.zero, title: const Text('Target date'), subtitle: Text(targetDate == null ? 'No target date' : targetDate!.toLocal().toString().split(' ').first), trailing: targetDate == null ? const Icon(Icons.calendar_today_outlined) : IconButton(tooltip: 'Clear target date', icon: const Icon(Icons.clear), onPressed: () => setState(() => targetDate = null)), onTap: () async { final selected = await showDatePicker(context: context, initialDate: targetDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (selected != null && mounted) setState(() => targetDate = selected); }),
    const SizedBox(height: 18), Text('Icon', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: _icons.map((icon) => ChoiceChip(label: Icon(icon), selected: selectedIcon == icon.codePoint, onSelected: (_) => setState(() => selectedIcon = icon.codePoint))).toList()),
    const SizedBox(height: 18), Text('Colour', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: AppColors.identityPalette.map((tone) => tone.toARGB32()).map((color) => InkWell(onTap: () => setState(() => selectedColor = color), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle, border: Border.all(color: selectedColor == color ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3)), child: selectedColor == color ? const Icon(Icons.check, color: AppColors.onPrimary, size: 17) : null))).toList()),
    const SizedBox(height: 28), FilledButton(onPressed: _save, child: Text(widget.goal == null ? 'Save goal' : 'Save changes')),
  ])));
  Future<void> _save() async { if (!form.currentState!.validate()) return; await ref.read(goalListProvider.notifier).save(Goal(id: widget.goal?.id, name: name.text.trim(), targetMinor: (double.parse(target.text) * 100).round(), currentMinor: starting.text.trim().isEmpty ? widget.goal?.currentMinor ?? 0 : (double.parse(starting.text) * 100).round(), targetDate: targetDate)); if (mounted) Navigator.pop(context); }
  @override void dispose() { name.dispose(); target.dispose(); starting.dispose(); super.dispose(); }
}
