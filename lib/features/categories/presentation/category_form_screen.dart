import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../budgets/providers/budget_provider.dart';
import '../../categorization/providers/merchant_rule_provider.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/entities/category.dart';
import '../providers/category_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late String _type;
  late int _color;
  late int _icon;

  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  static const List<IconData> _icons = [
    Icons.category_rounded,
    Icons.shopping_basket_outlined,
    Icons.restaurant_rounded,
    Icons.wifi_rounded,
    Icons.directions_car_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.favorite_outline_rounded,
    Icons.home_outlined,
    Icons.local_grocery_store_outlined,
    Icons.school_outlined,
    Icons.medical_services_outlined,
    Icons.work_outline_rounded,
    Icons.savings_outlined,
    Icons.subscriptions_outlined,
    Icons.flight_outlined,
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.category?.name ?? '');

    _nameController.addListener(_updatePreview);

    _type = widget.category?.type ?? 'expense';
    _color = widget.category?.color ?? AppColors.primary.toARGB32();
    _icon = widget.category?.icon ?? Icons.category.codePoint;
  }

  void _updatePreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_updatePreview);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final categoryName = _nameController.text.trim();

      final categoryWasRenamed =
          widget.category != null && widget.category!.name != categoryName;

      await ref
          .read(categoryListProvider.notifier)
          .save(
            Category(
              id: widget.category?.id,
              name: categoryName,
              icon: _icon,
              color: _color,
              type: _type,
            ),
          );

      if (categoryWasRenamed) {
        await Future.wait([
          ref.read(transactionListProvider.notifier).refresh(),
          ref.read(budgetListProvider.notifier).refresh(),
          ref.read(recurringListProvider.notifier).refresh(),
          ref.read(merchantRuleListProvider.notifier).refresh(),
        ]);
      }

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().toLowerCase().contains('unique') ||
                    error.toString().toLowerCase().contains('duplicate')
                ? 'A category with that name already exists.'
                : 'Could not save category. Please try again.',
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit category' : 'Add category',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
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
            _SectionHeading(
              title: 'Category details',
              subtitle: 'Organize transactions with a clear name and type.',
            ),
            const SizedBox(height: 12),
            _FormSurface(
              children: [
                const _FieldLabel(label: 'Category name', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: 60,
                  decoration: _inputDecoration(
                    context,
                    hint: 'e.g. Groceries',
                    icon: Icons.edit_note_rounded,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter a category name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const _FieldLabel(label: 'Category type', required: true),
                const SizedBox(height: 12),
                _CategoryTypeSelector(
                  selected: _type,
                  onChanged: (value) {
                    setState(() => _type = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Category appearance',
              subtitle: 'Choose an icon and color to identify this category.',
            ),
            const SizedBox(height: 12),
            _FormSurface(
              children: [
                const _FieldLabel(label: 'Icon'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _icons.map((iconData) {
                    final selected = _icon == iconData.codePoint;

                    return _IconOption(
                      icon: iconData,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _icon = iconData.codePoint;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Color'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppColors.identityPalette.map((tone) {
                    final value = tone.toARGB32();

                    return _ColorOption(
                      color: tone,
                      selected: _color == value,
                      onTap: () {
                        setState(() => _color = value);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Preview',
              subtitle: 'How your category will appear in SpenFlo.',
            ),
            const SizedBox(height: 12),
            _CategoryPreview(
              name: _nameController.text.trim().isEmpty
                  ? 'Category name'
                  : _nameController.text.trim(),
              type: _type,
              color: Color(_color),
              icon: _icon,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
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
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditing ? Icons.check_rounded : Icons.add_rounded,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing ? 'Save changes' : 'Save category',
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
// Category type selector
// ------------------------------------------------------------

class _CategoryTypeSelector extends StatelessWidget {
  const _CategoryTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final options = [
          _TypeOption(
            value: 'expense',
            label: 'Expense',
            icon: Icons.arrow_upward_rounded,
            selected: selected == 'expense',
            accent: colors.error,
            onTap: () => onChanged('expense'),
          ),
          _TypeOption(
            value: 'income',
            label: 'Income',
            icon: Icons.arrow_downward_rounded,
            selected: selected == 'income',
            accent: const Color(0xFF16A34A),
            onTap: () => onChanged('income'),
          ),
          _TypeOption(
            value: 'both',
            label: 'Both',
            icon: Icons.swap_horiz_rounded,
            selected: selected == 'both',
            accent: colors.primary,
            onTap: () => onChanged('both'),
          ),
        ];

        if (constraints.maxWidth < 300) {
          return Wrap(spacing: 8, runSpacing: 8, children: options);
        }

        return Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: options[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? accent.withValues(alpha: 0.09) : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? accent : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
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

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.10)
          : colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 19,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Category preview
// ------------------------------------------------------------

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });

  final String name;
  final String type;
  final Color color;
  final int icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              IconData(icon, fontFamily: 'MaterialIcons'),
              size: 24,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _typeLabel(type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_outline_rounded,
            color: colors.primary,
            size: 21,
          ),
        ],
      ),
    );
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'expense':
      return 'Expense category';
    case 'income':
      return 'Income category';
    case 'both':
      return 'Income & expense';
    default:
      return type;
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
