import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late TransactionType _type;
  late String _frequency;
  late DateTime _nextDate;

  DateTime? _endDate;
  int? _accountId;
  String? _category;

  bool _isSaving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.item?.title ?? '');

    _amountController = TextEditingController(
      text: widget.item == null
          ? ''
          : (widget.item!.amountMinor / 100).toStringAsFixed(2),
    );

    _notesController = TextEditingController(text: widget.item?.notes ?? '');

    _type = widget.item?.type ?? TransactionType.expense;
    _frequency = widget.item?.frequency ?? 'monthly';
    _nextDate = widget.item?.nextOccurrence ?? DateTime.now();

    _endDate = widget.item?.endDate;
    _accountId = widget.item?.accountId;
    _category = widget.item?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isEndDate}) async {
    final colors = Theme.of(context).colorScheme;

    final result = await showDatePicker(
      context: context,
      initialDate: isEndDate ? (_endDate ?? _nextDate) : _nextDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: colors.surface,
              headerBackgroundColor: colors.primary,
              headerForegroundColor: colors.onPrimary,
              dayForegroundColor: WidgetStatePropertyAll(colors.onSurface),
              todayForegroundColor: WidgetStatePropertyAll(colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      if (isEndDate) {
        _endDate = result;
      } else {
        _nextDate = result;
      }
    });
  }

  void _changeType(TransactionType value) {
    if (_type == value) return;

    setState(() {
      _type = value;
      _category = null;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) return;
    if (_accountId == null || _category == null) return;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(recurringListProvider.notifier)
          .save(
            RecurringTransaction(
              id: widget.item?.id,
              title: _titleController.text.trim(),
              amountMinor: (amount * 100).round(),
              type: _type,
              category: _category!,
              accountId: _accountId!,
              frequency: _frequency,
              nextOccurrence: _nextDate,
              startDate: widget.item?.startDate ?? _nextDate,
              endDate: _endDate,
              notes: _notesController.text.trim(),
              enabled: widget.item?.enabled ?? true,
            ),
          );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save recurring transaction. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final accounts = ref.watch(accountListProvider).value ?? [];

    final allCategories = ref.watch(categoryListProvider).value ?? [];

    final categories = allCategories
        .where(
          (category) => category.type == 'both' || category.type == _type.name,
        )
        .toList();

    final accountIds = accounts.map((a) => a.id).toSet();

    final selectedAccountId = accountIds.contains(_accountId)
        ? _accountId
        : accounts.isEmpty
        ? null
        : accounts.first.id;

    final categoryNames = categories.map((category) => category.name).toSet();

    final selectedCategory = categoryNames.contains(_category)
        ? _category
        : categories.isEmpty
        ? null
        : categories.first.name;

    // Match the original form's default-selection behavior while
    // keeping the dropdown values consistent with provider data.
    _accountId = selectedAccountId;
    _category = selectedCategory;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing
              ? 'Edit recurring transaction'
              : 'Add recurring transaction',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SectionHeading(
              title: 'Transaction type',
              subtitle: 'Choose how this payment affects your money.',
            ),
            const SizedBox(height: 12),
            _TransactionTypeSelector(value: _type, onChanged: _changeType),
            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Transaction details',
              subtitle: 'Set up the amount and account.',
            ),
            const SizedBox(height: 12),

            _FormSurface(
              children: [
                _FieldLabel(label: 'Title', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    context,
                    hint: 'e.g. Monthly rent',
                    icon: Icons.edit_note_rounded,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _FieldLabel(label: 'Amount', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    context,
                    hint: '0.00',
                    icon: Icons.attach_money_rounded,
                  ).copyWith(prefixText: r'$ '),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());

                    if (parsed == null || parsed <= 0) {
                      return 'Enter an amount';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _FieldLabel(label: 'Account', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: ValueKey('account-$selectedAccountId'),
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Choose an account',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem<int>(
                          value: account.id,
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _accountId = value);
                  },
                  validator: (value) =>
                      value == null ? 'Choose an account' : null,
                ),
                const SizedBox(height: 18),

                _FieldLabel(label: 'Category', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-${_type.name}-$selectedCategory'),
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Choose a category',
                    icon: Icons.category_outlined,
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category.name,
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _category = value);
                  },
                  validator: (value) =>
                      value == null ? 'Choose a category' : null,
                ),
              ],
            ),
            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Repeat schedule',
              subtitle: 'Choose when this transaction repeats.',
            ),
            const SizedBox(height: 12),

            _FormSurface(
              children: [
                _FieldLabel(label: 'Frequency', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Select frequency',
                    icon: Icons.repeat_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _frequency = value);
                    }
                  },
                ),
                const SizedBox(height: 18),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 330;

                    final startField = _DateSelectionField(
                      label: 'Next occurrence',
                      value: _nextDate,
                      icon: Icons.event_available_outlined,
                      onTap: () => _selectDate(isEndDate: false),
                    );

                    final endField = _DateSelectionField(
                      label: 'End date',
                      value: _endDate,
                      icon: Icons.event_busy_outlined,
                      onTap: () => _selectDate(isEndDate: true),
                      onClear: _endDate == null
                          ? null
                          : () {
                              setState(() => _endDate = null);
                            },
                    );

                    if (compact) {
                      return Column(
                        children: [
                          startField,
                          const SizedBox(height: 14),
                          endField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: startField),
                        const SizedBox(width: 12),
                        Expanded(child: endField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Leave the end date empty to keep '
                        'this recurring transaction active.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Additional notes',
              subtitle: 'Optional details for your records.',
            ),
            const SizedBox(height: 12),

            _FormSurface(
              children: [
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Add a note about this transaction...',
                    icon: Icons.notes_rounded,
                  ).copyWith(alignLabelWithHint: true),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: accounts.isEmpty || _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.onSurface.withValues(
                  alpha: 0.12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEditing ? Icons.check_rounded : Icons.add_rounded,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing
                              ? 'Save changes'
                              : 'Save recurring transaction',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

// ------------------------------------------------------------
// Transaction type selector
// ------------------------------------------------------------

class _TransactionTypeSelector extends StatelessWidget {
  const _TransactionTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _TypeOption(
            label: 'Expense',
            icon: Icons.arrow_upward_rounded,
            color: colors.error,
            selected: value == TransactionType.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeOption(
            label: 'Income',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF16A34A),
            selected: value == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? color.withValues(alpha: 0.09) : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? color : colors.onSurfaceVariant,
                size: 19,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared form components
// ------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          Text(
            '*',
            style: TextStyle(color: colors.error, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DateSelectionField extends StatelessWidget {
  const _DateSelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final dateText = value == null
        ? 'Optional'
        : MaterialLocalizations.of(context).formatMediumDate(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 8),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: value == null
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                        fontWeight: value == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Clear end date',
                      onPressed: onClear,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
}) {
  final colors = Theme.of(context).colorScheme;

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
    prefixIcon: Icon(icon, size: 20, color: colors.onSurfaceVariant),
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.error, width: 1.6),
    ),
  );
}
