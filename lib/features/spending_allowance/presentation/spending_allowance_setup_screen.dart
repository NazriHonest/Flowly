import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/spending_allowance.dart';
import '../providers/spending_allowance_provider.dart';

class SpendingAllowanceSetupScreen extends ConsumerStatefulWidget {
  const SpendingAllowanceSetupScreen({super.key});
  @override
  ConsumerState<SpendingAllowanceSetupScreen> createState() => _State();
}

class _State extends ConsumerState<SpendingAllowanceSetupScreen> {
  final formKey = GlobalKey<FormState>();
  final monthly = TextEditingController();
  final weekly = TextEditingController();
  final daily = TextEditingController();
  bool weeklyEnabled = false, dailyEnabled = false, repeats = true, saving = false, loaded = false;

  @override
  void dispose() { monthly.dispose(); weekly.dispose(); daily.dispose(); super.dispose(); }

  void load(SpendingAllowanceConfig? value) {
    if (loaded || value == null) return;
    loaded = true;
    monthly.text = (value.monthlyLimitMinor / 100).toStringAsFixed(2);
    weeklyEnabled = value.weeklyEnabled;
    dailyEnabled = value.dailyEnabled;
    if (value.weeklyLimitMinor != null) weekly.text = (value.weeklyLimitMinor! / 100).toStringAsFixed(2);
    if (value.dailyLimitMinor != null) daily.text = (value.dailyLimitMinor! / 100).toStringAsFixed(2);
    repeats = value.repeatsMonthly;
  }

  int? minor(String raw) {
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(raw.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 + int.parse((match.group(2) ?? '').padRight(2, '0').isEmpty ? '0' : (match.group(2) ?? '').padRight(2, '0'));
  }

  String? validateAmount(String? value) {
    final amount = minor(value ?? '');
    if (amount == null) return 'Enter a valid amount with up to two decimal places.';
    if (amount <= 0) return 'Amount must be greater than zero.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentAllowanceProvider);
    current.whenData(load);
    return Scaffold(
      appBar: AppBar(title: const Text('Set Spending Allowance')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('Set your spending limits and stay in control of your money.', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              _heading(context, 'Monthly Allowance'),
              _amount(monthly, 'Monthly Allowance (\$)', 'Your total spending limit for the month.'),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weekly Allowance'),
                subtitle: const Text('Set an optional spending limit for each Saturday–Friday week.'),
                value: weeklyEnabled,
                onChanged: (value) => setState(() => weeklyEnabled = value),
              ),
              if (weeklyEnabled) _amount(weekly, 'Weekly Limit (\$)', null),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily Allowance'),
                subtitle: const Text('Set an optional spending limit for each day.'),
                value: dailyEnabled,
                onChanged: (value) => setState(() => dailyEnabled = value),
              ),
              if (dailyEnabled) _amount(daily, 'Daily Limit (\$)', null),
              if (weeklyEnabled || dailyEnabled) ...[
                const SizedBox(height: 10),
                Text(
                  'Daily and weekly limits are independent controls and do not need to add up to the monthly limit.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              _heading(context, 'Monthly Renewal'),
              RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: true, groupValue: repeats, title: const Text('Repeat every month'), subtitle: const Text('Use these limits as the default for subsequent months.'), onChanged: (v) => setState(() => repeats = v!)),
              RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: false, groupValue: repeats, title: const Text('This month only'), subtitle: const Text('Apply this configuration only to the current month.'), onChanged: (v) => setState(() => repeats = v!)),
              const SizedBox(height: 16),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline), const SizedBox(width: 12), Expanded(child: Text('Your daily, weekly, and monthly limits track the same recorded expenses. They do not change your account balances or category budgets.', style: Theme.of(context).textTheme.bodySmall))]))),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Allowance'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)));
  Widget _amount(TextEditingController controller, String label, String? helper) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    decoration: InputDecoration(labelText: label, helperText: helper, prefixText: '\$ '),
    validator: validateAmount,
  );

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final now = DateTime.now();
      await ref.read(spendingAllowanceMutationsProvider).save(SpendingAllowanceConfig(
        monthStart: DateTime(now.year, now.month), monthlyLimitMinor: minor(monthly.text)!,
        weeklyEnabled: weeklyEnabled, weeklyLimitMinor: weeklyEnabled ? minor(weekly.text) : null,
        dailyEnabled: dailyEnabled, dailyLimitMinor: dailyEnabled ? minor(daily.text) : null,
        repeatsMonthly: repeats,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spending allowance saved.')));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the allowance. Please try again.')));
    } finally { if (mounted) setState(() => saving = false); }
  }
}
