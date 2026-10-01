import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/providers/category_provider.dart';
import '../domain/entities/budget.dart';
import '../providers/budget_provider.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, this.budget});
  final Budget? budget;
  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.budget?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.budget == null
        ? ''
        : (widget.budget!.amountMinor / 100).toStringAsFixed(2),
  );
  String? _category;
  late String _period = widget.budget?.period ?? 'monthly';
  late double _threshold = widget.budget?.alertThreshold ?? .8;
  late DateTime _start = widget.budget?.startDate ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    _category = widget.budget?.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryListProvider).value ?? [];
    if (_category == null && categories.isNotEmpty) {
      _category = categories.first.name;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.budget == null ? 'Add budget' : 'Edit budget'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Category', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.folder_outlined)),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.name,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: categories.isEmpty
                  ? null
                  : (value) => setState(() => _category = value),
              validator: (value) => value == null ? 'Choose a category' : null,
            ),
            const SizedBox(height: 18),
            Text('Amount', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount', prefixIcon: Icon(Icons.payments_outlined),
                prefixText: r'$ ',
              ),
              validator: (value) =>
                  double.tryParse(value ?? '') == null ||
                      double.parse(value!) <= 0
                  ? 'Enter a valid amount'
                  : null,
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 18),
            Text('Period', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'weekly', label: Text('Weekly')), ButtonSegment(value: 'monthly', label: Text('Monthly')), ButtonSegment(value: 'yearly', label: Text('Yearly'))], selected: {_period}, onSelectionChanged: (value) => setState(() => _period = value.first)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(
                MaterialLocalizations.of(context).formatMediumDate(_start),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: _start,
                );
                if (value != null) setState(() => _start = value);
              },
            ),
            const SizedBox(height: 18),
            Row(children: [const Text('Alert threshold'), const Spacer(), Text('${(_threshold * 100).round()}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800))]),
            Slider(
              value: _threshold,
              min: .5,
              max: 1,
              divisions: 10,
              label: '${(_threshold * 100).round()}%',
              onChanged: (value) => setState(() => _threshold = value),
            ),
            const SizedBox(height: 36),
            FilledButton(onPressed: _save, child: Text(widget.budget == null ? 'Save Budget' : 'Save Changes')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(budgetListProvider.notifier)
        .save(
          Budget(
            id: widget.budget?.id,
            name: _name.text.trim().isEmpty ? _category! : _name.text.trim(),
            category: _category!,
            amountMinor: (double.parse(_amount.text) * 100).round(),
            period: _period,
            startDate: _start,
            alertThreshold: _threshold,
          ),
        );
    if (mounted) Navigator.pop(context);
  }
}
