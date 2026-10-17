import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../accounts/domain/entities/account.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../categorization/providers/merchant_rule_provider.dart';
import '../domain/entities/transaction.dart';
import '../providers/transaction_provider.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late TransactionType _type;
  late DateTime _date;
  String? _category;
  int? _accountId;
  int? _destinationAccountId;
  bool _saving = false;

  bool get _editing => widget.transaction != null;
  bool get _transfer => _type == TransactionType.transfer;

  @override
  void initState() {
    super.initState();
    final original = widget.transaction;
    _amount = TextEditingController(
      text: original == null
          ? ''
          : (original.amountMinor / 100).toStringAsFixed(2),
    );
    _title = TextEditingController(text: original?.title ?? '');
    _notes = TextEditingController(text: original?.notes ?? '');
    _type = original?.type ?? TransactionType.expense;
    _date = original?.date ?? DateTime.now();
    _category = original?.category;
    _accountId = original?.accountId;
    _destinationAccountId = original?.destinationAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _changeType(TransactionType value) {
    if (_saving || _type == value) return;
    setState(() {
      _type = value;
      // A category selected for income may not be valid for expenses.
      _category = null;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _date = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _date.hour,
        _date.minute,
        _date.second,
        _date.millisecond,
        _date.microsecond,
      );
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || !parsed.isFinite) return;
    final minor = (parsed * 100).round();
    if (minor <= 0 || _accountId == null || (!_transfer && _category == null)) {
      return;
    }
    if (_transfer &&
        (_destinationAccountId == null ||
            _destinationAccountId == _accountId)) {
      return;
    }

    setState(() => _saving = true);
    var transactionSaved = false;
    try {
      final original = widget.transaction;
      await ref
          .read(transactionListProvider.notifier)
          .save(
            Transaction(
              id: original?.id,
              amountMinor: minor,
              type: _type,
              title: _transfer ? 'Transfer' : _title.text.trim(),
              category: _transfer ? 'Transfer' : _category!,
              accountId: _accountId!,
              destinationAccountId: _transfer ? _destinationAccountId : null,
              date: _date,
              source: original?.source ?? TransactionSource.manual,
              status: original?.status ?? ReviewStatus.confirmed,
              notes: _notes.text.trim(),
              providerTransactionAt: original?.providerTransactionAt,
              smsReceivedAt: original?.smsReceivedAt,
              createdAt: original?.createdAt,
            ),
          );
      transactionSaved = true;
      if (!mounted) return;

      final learnable =
          original != null &&
          (original.source == TransactionSource.smsLive ||
              original.source == TransactionSource.smsImport) &&
          original.category != _category &&
          !_transfer &&
          _title.text.trim().isNotEmpty;

      if (learnable) {
        final learn = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Learn this correction?'),
            content: Text(
              'Categorize future transactions from ${_title.text.trim()} as $_category?',
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
          try {
            await ref
                .read(merchantRuleListProvider.notifier)
                .save(_title.text.trim(), _category!);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Transaction saved, but the categorization rule could not be saved.',
                  ),
                ),
              );
            }
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transactionSaved
                ? 'Transaction saved, but a follow-up action failed.'
                : 'Could not save transaction. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accounts = ref.watch(accountListProvider).value ?? <Account>[];
    final categories = ref.watch(categoryListProvider).value ?? [];
    final matching = categories
        .where(
          (item) =>
              item.type == 'both' ||
              item.type ==
                  (_type == TransactionType.income ? 'income' : 'expense'),
        )
        .toList();

    final selectedAccount = accounts.any((a) => a.id == _accountId)
        ? _accountId
        : (accounts.isEmpty ? null : accounts.first.id);
    final destinationOptions = accounts
        .where((a) => a.id != selectedAccount)
        .toList();
    final selectedDestination =
        destinationOptions.any((a) => a.id == _destinationAccountId)
        ? _destinationAccountId
        : (destinationOptions.isEmpty ? null : destinationOptions.first.id);
    final selectedCategory = matching.any((c) => c.name == _category)
        ? _category
        : (matching.isEmpty ? null : matching.first.name);

    // Normalize defaults before submission without mutating state during build.
    _accountId = selectedAccount;
    _destinationAccountId = selectedDestination;
    _category = selectedCategory;

    final accent = _type == TransactionType.income
        ? AppColors.income
        : _transfer
        ? AppColors.transfer
        : AppColors.expense;
    final typeLabel = _type == TransactionType.income
        ? 'income'
        : _transfer
        ? 'transfer'
        : 'expense';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _editing ? 'Edit transaction' : 'Add $typeLabel',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _SectionHeading(
              'Transaction type',
              'Choose how this transaction affects your accounts.',
            ),
            const SizedBox(height: 12),
            _FormSurface(
              child: Row(
                children: [
                  _TypeTile(
                    label: 'Expense',
                    icon: Icons.arrow_upward_rounded,
                    selected: _type == TransactionType.expense,
                    accent: AppColors.expense,
                    onTap: () => _changeType(TransactionType.expense),
                  ),
                  const SizedBox(width: 8),
                  _TypeTile(
                    label: 'Income',
                    icon: Icons.arrow_downward_rounded,
                    selected: _type == TransactionType.income,
                    accent: AppColors.income,
                    onTap: () => _changeType(TransactionType.income),
                  ),
                  const SizedBox(width: 8),
                  _TypeTile(
                    label: 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    selected: _transfer,
                    accent: AppColors.transfer,
                    onTap: () => _changeType(TransactionType.transfer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeading('Amount', 'Enter the transaction amount.'),
            const SizedBox(height: 12),
            _FormSurface(
              child: TextFormField(
                controller: _amount,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                  hintText: '0.00',
                  hintStyle: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  filled: true,
                  fillColor: accent.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.primary, width: 1.6),
                  ),
                ),
                validator: (value) {
                  final number = double.tryParse((value ?? '').trim());
                  if (number == null ||
                      !number.isFinite ||
                      (number * 100).round() <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              _transfer ? 'Transfer details' : 'Transaction details',
              _transfer
                  ? 'Select the source and destination accounts.'
                  : 'Describe and categorize this transaction.',
            ),
            const SizedBox(height: 12),
            _FormSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_transfer) ...[
                    const _FieldLabel('Title / Payee'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        context,
                        'e.g. Groceries',
                        Icons.edit_note_rounded,
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _FieldLabel(_transfer ? 'From account' : 'Account'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey('source-$selectedAccount'),
                    initialValue: selectedAccount,
                    isExpanded: true,
                    decoration: _decoration(
                      context,
                      'Select an account',
                      Icons.account_balance_wallet_outlined,
                    ),
                    items: accounts
                        .where((a) => a.id != null)
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _accountId = value;
                            if (_destinationAccountId == value) {
                              _destinationAccountId = null;
                            }
                          }),
                    validator: (value) =>
                        value == null ? 'Create or choose an account' : null,
                  ),
                  if (_transfer) ...[
                    const SizedBox(height: 18),
                    const _FieldLabel('To account'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'destination-$selectedAccount-$selectedDestination',
                      ),
                      initialValue: selectedDestination,
                      isExpanded: true,
                      decoration: _decoration(
                        context,
                        'Select destination',
                        Icons.move_to_inbox_outlined,
                      ),
                      items: destinationOptions
                          .where((a) => a.id != null)
                          .map(
                            (a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(
                                a.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _destinationAccountId = value),
                      validator: (value) => value == null
                          ? 'Choose a different destination account'
                          : null,
                    ),
                    if (accounts.length < 2) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Transfers require at least two accounts.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 18),
                    const _FieldLabel('Category'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('category-${_type.name}-$selectedCategory'),
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: _decoration(
                        context,
                        'Choose a category',
                        Icons.folder_outlined,
                      ),
                      items: matching
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.name,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving || matching.isEmpty
                          ? null
                          : (value) => setState(() => _category = value),
                      validator: (value) =>
                          value == null ? 'Create or choose a category' : null,
                    ),
                    if (matching.isEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Create a category before saving this transaction.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeading(
              'Additional information',
              'Set the date and add an optional note.',
            ),
            const SizedBox(height: 12),
            _FormSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Date'),
                  const SizedBox(height: 8),
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _saving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                MaterialLocalizations.of(context)
                                    .formatMediumDate(_date),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Notes (optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      context,
                      'Add a note...',
                      Icons.notes_rounded,
                    ).copyWith(alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed:
                  _saving ||
                      accounts.isEmpty ||
                      (_transfer && accounts.length < 2)
                  ? null
                  : _save,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: colors.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _editing ? Icons.check_rounded : Icons.add_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _editing
                              ? 'Save changes'
                              : _transfer
                              ? 'Save transfer'
                              : 'Save transaction',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected ? accent.withValues(alpha: 0.10) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? accent : colors.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? accent : colors.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(BuildContext context, String hint, IconData icon) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    prefixIcon: Icon(icon, size: 20, color: colors.onSurfaceVariant),
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary, 1.6),
    errorBorder: border(colors.error),
    focusedErrorBorder: border(colors.error, 1.6),
    disabledBorder: border(colors.outlineVariant),
  );
}
