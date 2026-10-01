import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../categorization/providers/merchant_rule_provider.dart';
import '../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';
import '../../../core/theme/app_colors.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});
  final Transaction? transaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(
    text: widget.transaction == null
        ? ''
        : (widget.transaction!.amountMinor / 100).toStringAsFixed(2),
  );
  late final title = TextEditingController(
    text: widget.transaction?.title ?? '',
  );
  late final notes = TextEditingController(
    text: widget.transaction?.notes ?? '',
  );
  late TransactionType type =
      widget.transaction?.type ?? TransactionType.expense;
  late DateTime date = widget.transaction?.date ?? DateTime.now();
  String? category;
  int? accountId;
  int? destinationAccountId;

  @override
  void initState() {
    super.initState();
    category = widget.transaction?.category;
    accountId = widget.transaction?.accountId;
    destinationAccountId = widget.transaction?.destinationAccountId;
  }

  @override
  void dispose() {
    amount.dispose();
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountListProvider).value ?? [];
    final availableCategories = ref.watch(categoryListProvider).value ?? [];
    final transfer = type == TransactionType.transfer;
    final matchingCategories = availableCategories
        .where(
          (item) =>
              item.type == 'both' ||
              item.type ==
                  (type == TransactionType.income ? 'income' : 'expense'),
        )
        .toList();
    if (!transfer &&
        (category == null ||
            !matchingCategories.any((item) => item.name == category))) {
      category = matchingCategories.isEmpty
          ? null
          : matchingCategories.first.name;
    }
    accountId ??= accounts.isEmpty ? null : accounts.first.id;
    if (destinationAccountId == null && accounts.length > 1) {
      destinationAccountId = accounts
          .firstWhere((account) => account.id != accountId)
          .id;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null
              ? 'Edit transaction'
              : switch (type) {
                  TransactionType.expense => 'Add expense',
                  TransactionType.income => 'Add income',
                  TransactionType.transfer => 'Add transfer',
                },
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const SizedBox(height: 2),
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
                ButtonSegment(
                  value: TransactionType.transfer,
                  label: Text('Transfer'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                'AMOUNT',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
              ),
            ),
            TextFormField(
              controller: amount,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: type == TransactionType.income
                    ? AppColors.income
                    : type == TransactionType.transfer
                    ? AppColors.transfer
                    : AppColors.expense,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                border: InputBorder.none,
              ),
              validator: (value) =>
                  double.tryParse(value ?? '') == null ||
                      double.parse(value!) <= 0
                  ? 'Enter an amount greater than zero'
                  : null,
            ),
            const SizedBox(height: 16),
            if (transfer) ...[
              _accountField(
                accounts,
                label: 'From account',
                value: accountId,
                onChanged: (value) => setState(() => accountId = value),
              ),
              const SizedBox(height: 12),
              _accountField(
                accounts,
                label: 'To account',
                value: destinationAccountId,
                onChanged: (value) =>
                    setState(() => destinationAccountId = value),
                validator: (value) => value == null
                    ? 'Choose a destination account'
                    : value == accountId
                    ? 'Choose a different account'
                    : null,
              ),
            ] else ...[
              TextFormField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title / Payee',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                MaterialLocalizations.of(context).formatMediumDate(date),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: date,
                );
                if (selected != null) {
                  setState(
                    () => date = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                      date.hour,
                      date.minute,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            if (!transfer) ...[
              _accountField(
                accounts,
                label: 'Account',
                value: accountId,
                onChanged: (value) => setState(() => accountId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: matchingCategories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: matchingCategories.isEmpty
                    ? null
                    : (value) => setState(() => category = value),
                validator: (value) =>
                    value == null ? 'Create or choose a category' : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add a note (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: accounts.isEmpty ? null : () => _save(context),
              child: Text(
                type == TransactionType.transfer
                    ? 'Save transfer'
                    : widget.transaction == null
                    ? 'Save transaction'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountField(
    List<dynamic> accounts, {
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
    FormFieldValidator<int>? validator,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    items: accounts
        .map<DropdownMenuItem<int>>(
          (account) => DropdownMenuItem(
            value: account.id as int?,
            child: Text(account.name as String),
          ),
        )
        .toList(),
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (value) => value == null ? 'Create or choose an account' : null,
  );

  Future<void> _save(BuildContext context) async {
    if (!form.currentState!.validate()) return;
    final transfer = type == TransactionType.transfer;
    await ref
        .read(transactionListProvider.notifier)
        .save(
          Transaction(
            id: widget.transaction?.id,
            amountMinor: (double.parse(amount.text) * 100).round(),
            type: type,
            title: transfer ? 'Transfer' : title.text.trim(),
            category: transfer ? 'Transfer' : category!,
            accountId: accountId!,
            destinationAccountId: transfer ? destinationAccountId : null,
            date: date,
            source: widget.transaction?.source ?? TransactionSource.manual,
            status: widget.transaction?.status ?? ReviewStatus.confirmed,
            notes: notes.text.trim(),
            providerTransactionAt: widget.transaction?.providerTransactionAt,
            smsReceivedAt: widget.transaction?.smsReceivedAt,
            createdAt: widget.transaction?.createdAt,
          ),
        );
    final original = widget.transaction;
    final changedDetectedCategory =
        original != null &&
        (original.source == TransactionSource.smsLive ||
            original.source == TransactionSource.smsImport) &&
        original.category != category &&
        !transfer &&
        title.text.trim().isNotEmpty;
    if (changedDetectedCategory && context.mounted) {
      final learn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Learn this correction?'),
          content: Text(
            'Categorize future transactions from ${title.text.trim()} as $category?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Learn rule'),
            ),
          ],
        ),
      );
      if (learn == true) {
        await ref
            .read(merchantRuleListProvider.notifier)
            .save(title.text.trim(), category!);
      }
    }
    if (context.mounted) Navigator.pop(context);
  }
}
