import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/account.dart';
import '../providers/account_provider.dart';
import '../../../core/theme/app_colors.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key, this.account});
  final Account? account;
  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.account?.name ?? '');
  late final balance = TextEditingController(
    text: widget.account == null
        ? '0.00'
        : (widget.account!.openingBalanceMinor / 100).toStringAsFixed(2),
  );
  late String type = widget.account?.type ?? 'cash';
  late String currency = widget.account?.currency ?? 'USD';
  late int color = widget.account?.color ?? AppColors.primary.toARGB32();
  late int icon = widget.account?.icon ?? Icons.account_balance_wallet.codePoint;
  static const _icons = [
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.savings,
    Icons.credit_card,
    Icons.phone_android,
  ];
  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.account == null ? 'Add account' : 'Edit account'),
    ),
    body: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Account name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter an account name' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(
                value: 'mobile_money',
                child: Text('Mobile money'),
              ),
              DropdownMenuItem(value: 'credit', child: Text('Credit')),
            ],
            onChanged: (value) => setState(() => type = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const [
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'KES', child: Text('KES')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            ],
            onChanged: (value) => setState(() => currency = value!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Opening balance',
              prefixText: r'$ ',
            ),
            validator: (value) => double.tryParse(value ?? '') == null
                ? 'Enter a valid balance'
                : null,
          ),
          const SizedBox(height: 20),
          const Text('Icon'),
          Wrap(
            spacing: 8,
            children: _icons.map((value) => ChoiceChip(
              label: Icon(value),
              selected: icon == value.codePoint,
              onSelected: (_) => setState(() => icon = value.codePoint),
            )).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Color'),
          Wrap(
            spacing: 8,
            children: AppColors.identityPalette
                    .map((tone) => tone.toARGB32())
                    .map(
                      (value) => ChoiceChip(
                        label: const Text(''),
                        avatar: CircleAvatar(backgroundColor: Color(value)),
                        selected: color == value,
                        onSelected: (_) => setState(() => color = value),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(
              widget.account == null ? 'Save account' : 'Save changes',
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    await ref
        .read(accountListProvider.notifier)
        .save(
          Account(
            id: widget.account?.id,
            name: name.text.trim(),
            openingBalanceMinor: (double.parse(balance.text) * 100).round(),
            color: color,
            icon: icon,
            type: type,
            currency: currency,
          ),
        );
    if (mounted) Navigator.pop(context);
  }
}
