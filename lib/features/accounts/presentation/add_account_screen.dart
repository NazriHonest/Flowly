import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/entities/account.dart';
import '../providers/account_provider.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  late String _type;
  late String _currency;
  late int _color;
  late int _icon;

  bool _isSaving = false;

  bool get _isEditing => widget.account != null;

  static const _icons = [
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.savings,
    Icons.credit_card,
    Icons.phone_android,
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.account?.name ?? '');

    _balanceController = TextEditingController(
      text: widget.account == null
          ? '0.00'
          : (widget.account!.openingBalanceMinor / 100).toStringAsFixed(2),
    );

    _type = widget.account?.type ?? 'cash';
    _currency = widget.account?.currency ?? 'USD';
    _color = widget.account?.color ?? AppColors.primary.toARGB32();
    _icon = widget.account?.icon ?? Icons.account_balance_wallet.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final parsedBalance = double.tryParse(_balanceController.text.trim());

    if (parsedBalance == null || !parsedBalance.isFinite) return;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(accountListProvider.notifier)
          .save(
            Account(
              id: widget.account?.id,
              name: _nameController.text.trim(),
              openingBalanceMinor: (parsedBalance * 100).round(),
              color: _color,
              icon: _icon,
              type: _type,
              currency: _currency,
            ),
          );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save account. Please try again.'),
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
          _isEditing ? 'Edit account' : 'Add account',
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
              title: 'Account details',
              subtitle: 'Set up the account you want to track.',
            ),
            const SizedBox(height: 12),

            _FormSurface(
              children: [
                const _FieldLabel(label: 'Account name', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    context,
                    hint: 'e.g. My wallet',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter an account name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                const _FieldLabel(label: 'Account type', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Select account type',
                    icon: Icons.category_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(
                      value: 'mobile_money',
                      child: Text('Mobile money'),
                    ),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                ),
                const SizedBox(height: 18),

                const _FieldLabel(label: 'Currency', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    context,
                    hint: 'Select currency',
                    icon: Icons.currency_exchange_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('US Dollar (\$)'),
                    ),
                    DropdownMenuItem(
                      value: 'SOS',
                      child: Text('Somali Shilling (SOS)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _currency = value);
                    }
                  },
                ),
                const SizedBox(height: 18),

                const _FieldLabel(label: 'Opening balance', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^-?\d*\.?\d{0,2}'),
                    ),
                  ],
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    context,
                    hint: '0.00',
                    icon: Icons.payments_outlined,
                  ).copyWith(prefixText: _currency == 'USD' ? r'$ ' : 'SOS '),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());

                    if (parsed == null || !parsed.isFinite) {
                      return 'Enter a valid balance';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the amount this account '
                  'started with.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            _SectionHeading(
              title: 'Account appearance',
              subtitle:
                  'Choose an icon and color to identify '
                  'this account.',
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
                      accent: Color(_color),
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

            const SizedBox(height: 24),

            _AccountPreview(
              name: _nameController.text.trim().isEmpty
                  ? 'My account'
                  : _nameController.text.trim(),
              type: _type,
              currency: _currency,
              icon: _icon,
              accent: Color(_color),
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
                          _isEditing ? 'Save changes' : 'Save account',
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
// Section heading
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

// ------------------------------------------------------------
// Form label
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// Form surface
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// Icon selector
// ------------------------------------------------------------

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.10)
          : colors.surfaceContainerHighest.withValues(alpha: 0.55),
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

// ------------------------------------------------------------
// Color selector
// ------------------------------------------------------------

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
        width: 43,
        height: 43,
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
                  size: 18,
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
// Account preview
// ------------------------------------------------------------

class _AccountPreview extends StatelessWidget {
  const _AccountPreview({
    required this.name,
    required this.type,
    required this.currency,
    required this.icon,
    required this.accent,
  });

  final String name;
  final String type;
  final String currency;
  final int icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 12),
          child: Text(
            'Preview',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
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
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  IconData(icon, fontFamily: 'MaterialIcons'),
                  color: colors.onSurface,
                  size: 24,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currency,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'cash':
      return 'Cash';
    case 'bank':
      return 'Bank';
    case 'mobile_money':
      return 'Mobile money';
    case 'credit':
      return 'Credit';
    default:
      return type;
  }
}

// ------------------------------------------------------------
// Shared input decoration
// ------------------------------------------------------------

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
