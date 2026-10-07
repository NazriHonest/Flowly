import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/entities/goal.dart';
import '../providers/goal_provider.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goal});

  final Goal? goal;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _startingController;

  DateTime? _targetDate;
  bool _saving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.goal?.name ?? '');

    _targetController = TextEditingController(
      text: widget.goal == null
          ? ''
          : (widget.goal!.targetMinor / 100).toStringAsFixed(2),
    );

    _startingController = TextEditingController(
      text: widget.goal == null
          ? ''
          : (widget.goal!.currentMinor / 100).toStringAsFixed(2),
    );

    _targetDate = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _startingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit goal' : 'Create goal')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _GoalHero(isEditing: _isEditing),

              const SizedBox(height: 28),

              const _SectionHeader(
                title: 'Goal details',
                subtitle: 'Set what you are saving for and how much you want to reach.',
              ),

              const SizedBox(height: 14),

              _FormCard(
                children: [
                  const _FieldLabel(
                    icon: Icons.flag_outlined,
                    title: 'Goal name',
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Emergency fund',
                      prefixIcon: Icon(Icons.flag_outlined),
                      counterText: '',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter a goal name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 22),

                  const _FieldLabel(
                    icon: Icons.track_changes_outlined,
                    title: 'Target amount',
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.payments_outlined),
                      prefixText: r'$ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');

                      if (amount == null || amount <= 0) {
                        return 'Enter a valid target amount';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 7),

                  Text(
                    'The total amount you want to save for this goal.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              _SectionHeader(
                title: _isEditing ? 'Current savings' : 'Starting progress',
                subtitle: _isEditing
                    ? 'This is the amount currently saved toward this goal.'
                    : 'Already have money saved? Add it as your starting amount.',
              ),

              const SizedBox(height: 14),

              _FormCard(
                children: [
                  _FieldLabel(
                    icon: Icons.account_balance_wallet_outlined,
                    title: _isEditing ? 'Saved amount' : 'Starting amount',
                    optional: !_isEditing,
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _startingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      prefixText: r'$ ',
                      helperText: _isEditing
                          ? null
                          : 'Leave empty to start from \$0.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final amount = double.tryParse(value.trim());

                      if (amount == null || amount < 0) {
                        return 'Enter a valid saved amount';
                      }

                      return null;
                    },
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: 10),

                    _InfoMessage(
                      icon: Icons.info_outline_rounded,
                      message: 'Changing this amount updates the current saved value for this goal.',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 26),

              const _SectionHeader(
                title: 'Target date',
                subtitle: 'Add a deadline to help you stay focused. This is optional.',
              ),

              const SizedBox(height: 14),

              _TargetDateSelector(
                date: _targetDate,
                onSelect: _pickTargetDate,
                onClear: _targetDate == null
                    ? null
                    : () {
                        setState(() {
                          _targetDate = null;
                        });
                      },
              ),

              const SizedBox(height: 26),

              _GoalPreview(
                name: _nameController.text.trim(),
                targetMinor: _parseMinor(_targetController.text),
                currentMinor: _parseMinor(_startingController.text),
                targetDate: _targetDate,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
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
                              : Icons.flag_outlined,
                        ),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _isEditing
                        ? 'Save changes'
                        : 'Create goal',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _isEditing
                    ? 'Your goal will be updated with these changes.'
                    : 'You can add contributions and update this goal later.',
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

  Future<void> _pickTargetDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _targetDate = selected;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final targetAmount = double.parse(_targetController.text.trim());

    final startingText = _startingController.text.trim();

    final currentAmount = startingText.isEmpty
        ? widget.goal?.currentMinor ?? 0
        : double.parse(startingText);

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(goalListProvider.notifier)
          .save(
            Goal(
              id: widget.goal?.id,

              // Preserve an existing linked account.
              accountId: widget.goal?.accountId,

              name: _nameController.text.trim(),

              targetMinor: (targetAmount * 100).round(),

              currentMinor: (currentAmount * 100).round(),

              targetDate: _targetDate,
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
          content: Text('Couldn’t save the goal. Please try again.'),
        ),
      );
    }
  }

  int _parseMinor(String value) {
    final amount = double.tryParse(value.trim());

    if (amount == null || amount < 0) {
      return 0;
    }

    return (amount * 100).round();
  }
}

class _GoalHero extends StatelessWidget {
  const _GoalHero({required this.isEditing});

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
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.flag_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Update your goal' : 'Build toward something',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isEditing
                      ? 'Adjust your target, savings progress or target date.'
                      : 'Create a savings target and track your progress over time.',
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
          const SizedBox(width: 7),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Optional',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetDateSelector extends StatelessWidget {
  const _TargetDateSelector({
    required this.date,
    required this.onSelect,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date == null
                          ? 'No target date'
                          : MaterialLocalizations.of(context)
                                .formatMediumDate(date!),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      date == null
                          ? 'Tap to choose a date'
                          : 'Target completion date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              if (onClear != null)
                IconButton(
                  tooltip: 'Clear target date',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPreview extends StatelessWidget {
  const _GoalPreview({
    required this.name,
    required this.targetMinor,
    required this.currentMinor,
    required this.targetDate,
  });

  final String name;
  final int targetMinor;
  final int currentMinor;
  final DateTime? targetDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final progress = targetMinor <= 0 ? 0.0 : currentMinor / targetMinor;

    final remaining = (targetMinor - currentMinor).clamp(0, targetMinor);

    final completed = targetMinor > 0 && currentMinor >= targetMinor;

    final displayName = name.isEmpty ? 'Your savings goal' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Preview',
          subtitle: 'A quick look at your goal progress.',
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check_circle_outline_rounded
                          : Icons.flag_outlined,
                      color: completed ? AppColors.income : AppColors.primary,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          targetDate == null
                              ? 'No target date'
                              : 'Target ${MaterialLocalizations.of(context).formatMediumDate(targetDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (completed ? AppColors.income : AppColors.primary)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      completed ? 'Completed' : '${(progress * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: completed ? AppColors.income : AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _PreviewAmount(
                      label: 'SAVED',
                      amountMinor: currentMinor,
                    ),
                  ),
                  Expanded(
                    child: _PreviewAmount(
                      label: 'TARGET',
                      amountMinor: targetMinor,
                      alignRight: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  color: completed ? AppColors.income : AppColors.primary,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                completed
                    ? 'Goal reached'
                    : '\$${(remaining / 100).toStringAsFixed(2)} remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: completed ? AppColors.income : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewAmount extends StatelessWidget {
  const _PreviewAmount({
    required this.label,
    required this.amountMinor,
    this.alignRight = false,
  });

  final String label;
  final int amountMinor;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '\$${(amountMinor / 100).toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
