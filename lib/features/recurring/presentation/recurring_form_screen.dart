import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../transactions/domain/entities/transaction.dart';
import '../domain/entities/recurring_transaction.dart';
import '../providers/recurring_provider.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.item});
  final RecurringTransaction? item;
  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.item?.title ?? '');
  late final amount = TextEditingController(
    text: widget.item == null
        ? ''
        : (widget.item!.amountMinor / 100).toStringAsFixed(2),
  );
  late final notes = TextEditingController(text: widget.item?.notes ?? '');
  late TransactionType type = widget.item?.type ?? TransactionType.expense;
  late String frequency = widget.item?.frequency ?? 'monthly';
  late DateTime next = widget.item?.nextOccurrence ?? DateTime.now();
  DateTime? end;
  int? accountId;
  String? category;
  @override
  void initState() {
    super.initState();
    end = widget.item?.endDate;
    accountId = widget.item?.accountId;
    category = widget.item?.category;
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _date({required bool ending}) async {
    final result = await showDatePicker(
      context: context,
      initialDate: ending ? end ?? next : next,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) {
      setState(() {
        if (ending) {
          end = result;
        } else {
          next = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountListProvider).value ?? [];
    final allCategories = ref.watch(categoryListProvider).value ?? [];
    final categories = allCategories
        .where((c) => c.type == 'both' || c.type == type.name)
        .toList();
    accountId ??= accounts.isEmpty ? null : accounts.first.id;
    if (!categories.any((c) => c.name == category)) {
      category = categories.isEmpty ? null : categories.first.name;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null
              ? 'Add recurring transaction'
              : 'Edit recurring transaction',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.sell_outlined)),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a title' : null,
            ),
            TextFormField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.payments_outlined), prefixText: r'$ '),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Enter an amount'
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_outlined)),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => accountId = v),
              validator: (v) => v == null ? 'Choose an account' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.folder_outlined)),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => category = v),
              validator: (v) => v == null ? 'Choose a category' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Frequency', prefixIcon: Icon(Icons.repeat_rounded)),
              items: const [
                'daily',
                'weekly',
                'monthly',
                'yearly',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => frequency = v!),
            ),
            Row(children: [Expanded(child: _dateField(context, label: 'Start date', value: next, onTap: () => _date(ending: false))), const SizedBox(width: 12), Expanded(child: _dateField(context, label: 'End date', value: end, onTap: () => _date(ending: true)))]),
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: accounts.isEmpty ? null : _save,
              child: Text(widget.item == null ? 'Save recurring transaction' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    await ref
        .read(recurringListProvider.notifier)
        .save(
          RecurringTransaction(
            id: widget.item?.id,
            title: title.text.trim(),
            amountMinor: (double.parse(amount.text) * 100).round(),
            type: type,
            category: category!,
            accountId: accountId!,
            frequency: frequency,
            nextOccurrence: next,
            startDate: widget.item?.startDate ?? next,
            endDate: end,
            notes: notes.text.trim(),
            enabled: widget.item?.enabled ?? true,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Widget _dateField(BuildContext context, {required String label, required DateTime? value, required VoidCallback onTap}) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)), child: Text(value == null ? 'Optional' : MaterialLocalizations.of(context).formatMediumDate(value))));
}
