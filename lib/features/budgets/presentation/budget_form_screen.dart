import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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

  late final TextEditingController _name = TextEditingController(
    text: widget.budget?.name ?? '',
  );

  late final TextEditingController _amount = TextEditingController(
    text: widget.budget == null
        ? ''
        : (widget.budget!.amountMinor / 100).toStringAsFixed(2),
  );

  String? _category;

  late String _period = widget.budget?.period ?? 'monthly';

  late double _threshold = widget.budget?.alertThreshold ?? 0.8;

  late DateTime _start = widget.budget?.startDate ?? DateTime.now();

  bool _saving = false;

  bool get _isEditing => widget.budget != null;

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final categories = ref.watch(categoryListProvider).value ?? [];

    if (_category == null && categories.isNotEmpty) {
      _category = categories.first.name;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit budget' : 'Create budget')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _FormHero(isEditing: _isEditing),

              const SizedBox(height: 28),

              const _SectionHeader(
                title: 'Budget details',
                subtitle: 'Choose what you want to track and set your spending limit.',
              ),

              const SizedBox(height: 14),

              _FormCard(
                children: [
                  _FieldLabel(
                    icon: Icons.edit_outlined,
                    title: 'Budget name',
                    optional: true,
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: _category == null
                          ? 'e.g. Monthly food'
                          : 'e.g. $_category budget',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Leave blank to use the category name.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _FieldLabel(
                    icon: Icons.category_outlined,
                    title: 'Category',
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choose a category',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.name,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: categories.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _category = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Choose a category';
                      }

                      return null;
                    },
                  ),

                  if (categories.isEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'No categories are available. Create a category before adding a budget.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 22),

                  const _FieldLabel(
                    icon: Icons.payments_outlined,
                    title: 'Budget amount',
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      prefixText: r'$ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');

                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }

                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const _SectionHeader(
                title: 'Budget schedule',
                subtitle: 'Choose how often this budget applies.',
              ),

              const SizedBox(height: 14),

              _FormCard(
                children: [
                  const _FieldLabel(
                    icon: Icons.calendar_view_week_outlined,
                    title: 'Period',
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<String>(
                          value: 'weekly',
                          icon: Icon(
                            Icons.calendar_view_week_outlined,
                            size: 17,
                          ),
                          label: Text('Weekly'),
                        ),
                        ButtonSegment<String>(
                          value: 'monthly',
                          icon: Icon(Icons.calendar_month_outlined, size: 17),
                          label: Text('Monthly'),
                        ),
                        ButtonSegment<String>(
                          value: 'yearly',
                          icon: Icon(Icons.calendar_today_outlined, size: 17),
                          label: Text('Yearly'),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (value) {
                        setState(() {
                          _period = value.first;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _FieldLabel(
                    icon: Icons.event_outlined,
                    title: 'Start date',
                  ),

                  const SizedBox(height: 10),

                  _DateSelector(date: _start, onTap: _pickStartDate),
                ],
              ),

              const SizedBox(height: 26),

              const _SectionHeader(
                title: 'Spending alert',
                subtitle: 'Choose when SpenFlo should consider this budget near its limit.',
              ),

              const SizedBox(height: 14),

              _ThresholdCard(
                threshold: _threshold,
                onChanged: (value) {
                  setState(() {
                    _threshold = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving || categories.isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Icon(
                          _isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.add_circle_outline_rounded,
                        ),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _isEditing
                        ? 'Save changes'
                        : 'Create budget',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _isEditing
                    ? 'Your existing budget will be updated with these changes.'
                    : 'You can edit or archive this budget later.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _start,
    );

    if (value == null || !mounted) {
      return;
    }

    setState(() {
      _start = value;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_form.currentState!.validate()) {
      return;
    }

    if (_category == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
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

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save the budget. Please try again.'),
        ),
      );
    }
  }
}

class _FormHero extends StatelessWidget {
  const _FormHero({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.savings_outlined,
              color: AppColors.primary,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Update your budget' : 'Plan your spending',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isEditing
                      ? 'Adjust the limit, schedule or alert for this budget.'
                      : 'Set a spending limit and SpenFlo will help you track your progress.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.icon,
    required this.title,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),

        const SizedBox(width: 7),

        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            'Optional',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starts on',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.threshold, required this.onChanged});

  final double threshold;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final percentage = (threshold * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.warning,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert threshold',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Near-limit status starts at this percentage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percentage%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Slider(
            value: threshold,
            min: 0.5,
            max: 1.0,
            divisions: 10,
            label: '$percentage%',
            onChanged: onChanged,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '50%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '100%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This budget will be shown as near its limit after you use $percentage% of the budget.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
