import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/domain/entities/account.dart';
import '../../accounts/providers/account_provider.dart';
import '../../sms_detection/presentation/historical_import_screen.dart';
import '../../sms_detection/presentation/sms_permission_education_screen.dart';
import '../../sms_detection/providers/automatic_detection_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  String currency = 'KES';
  bool automatic = false;
  final account = TextEditingController();
  static const steps = <_StepData>[
    _StepData(
      Icons.account_balance_wallet_outlined,
      'Take control of your finances',
      'Flowly helps you understand your money, privately and clearly.',
    ),
    _StepData(
      Icons.receipt_long_outlined,
      'Track transactions',
      'Automatically when available. Always in your control.',
    ),
    _StepData(
      Icons.bar_chart_rounded,
      'Set budgets',
      'Stay on track and get nudges before you overspend.',
    ),
    _StepData(
      Icons.track_changes_rounded,
      'Reach your goals',
      'Save for what matters and watch your progress build.',
    ),
    _StepData(
      Icons.currency_exchange_rounded,
      'Choose your currency',
      'Pick the currency you use most. You can change this any time in Settings.',
    ),
    _StepData(
      Icons.shield_outlined,
      'Your privacy matters',
      'Financial SMS processing happens on this device. Automatic detection is optional.',
    ),
    _StepData(
      Icons.sms_outlined,
      'Automatic transaction detection',
      'Flowly can detect supported financial messages locally. You can continue completely manually.',
    ),
    _StepData(
      Icons.account_balance_outlined,
      'Create your first account',
      'Optional — you can add accounts later.',
    ),
    _StepData(
      Icons.download_for_offline_outlined,
      'Import past transactions?',
      'Optional — scan past financial messages after setup.',
    ),
    _StepData(
      Icons.check_rounded,
      'You’re all set!',
      'Your private financial space is ready whenever you are.',
    ),
  ];
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    await prefs.setString('defaultCurrency', currency);
    await ref.read(automaticDetectionProvider.notifier).setEnabled(automatic);
    MoneyFormatter.configure(currency);
    if (account.text.trim().isNotEmpty) {
      await ref
          .read(accountListProvider.notifier)
          .save(
            Account(
              name: account.text.trim(),
              openingBalanceMinor: 0,
              color: AppColors.primary.toARGB32(),
              type: 'cash',
              currency: currency,
            ),
          );
    }
    widget.onComplete();
  }

  @override
  void dispose() {
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = steps[step];
    final last = step == steps.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              Row(
                children: [
                  if (step > 0)
                    IconButton(
                      onPressed: () => setState(() => step--),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: () => setState(() => step = steps.length - 1),
                      child: const Text('Skip'),
                    ),
                ],
              ),
              const Spacer(),
              _Illustration(
                icon: data.icon,
                accent: step == 2 ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(height: 28),
              Text(
                data.title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(data.message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (step == 4) _CurrencyPicker(
                selected: currency,
                onChanged: (value) => setState(() => currency = value),
              ),
              if (step == 5) const _PrivacyPoints(),
              if (step == 6)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable automatic detection'),
                  subtitle: const Text(
                    'Permission is requested only after you choose to enable it.',
                  ),
                  value: automatic,
                  onChanged: (value) => setState(() => automatic = value),
                ),
              if (step == 7) ...[
                TextField(
                  controller: account,
                  decoration: const InputDecoration(
                    labelText: 'Account name',
                    hintText: 'e.g. Checking Account',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(
                    labelText: 'Account currency',
                  ),
                  items: const ['KES', 'USD', 'EUR', 'GBP']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setState(() => currency = value!),
                ),
              ],
              if (step == 8)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoricalImportScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Import now'),
                ),
              if (step < 4) _Dots(current: step),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? _finish
                      : () async {
                          if (step == 6 && automatic) {
                            final enabled = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SmsPermissionEducationScreen(),
                              ),
                            );
                            if (enabled != true && mounted) {
                              setState(() => automatic = false);
                            }
                          }
                          if (mounted) setState(() => step++);
                        },
                  child: Text(
                    last
                        ? 'Go to Dashboard'
                        : step == 6 && !automatic
                        ? 'Not Now'
                        : 'Continue',
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

class _StepData {
  const _StepData(this.icon, this.title, this.message);
  final IconData icon;
  final String title, message;
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: 116,
    height: 116,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: .12),
      border: Border.all(color: accent.withValues(alpha: .15), width: 8),
    ),
    child: Icon(icon, color: accent, size: 47),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current});
  final int current;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 5,
          width: i == current ? 20 : 5,
          decoration: BoxDecoration(
            color: i == current
                ? AppColors.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ),
  );
}

class _PrivacyPoints extends StatelessWidget {
  const _PrivacyPoints();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ListTile(
        leading: Icon(Icons.phone_android_outlined),
        title: Text('Processed on your device'),
        subtitle: Text('Nothing is sent to a server.'),
      ),
      ListTile(
        leading: Icon(Icons.sms_outlined),
        title: Text('Raw SMS is transient'),
        subtitle: Text('Only normalized financial details are kept.'),
      ),
      ListTile(
        leading: Icon(Icons.check_circle_outline),
        title: Text('Your data stays local'),
        subtitle: Text('Exports and backups exclude raw SMS.'),
      ),
    ],
  );
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: ['KES', 'USD', 'EUR', 'GBP']
        .map((code) => ChoiceChip(
              label: Text(code),
              selected: selected == code,
              onSelected: (_) => onChanged(code),
            ))
        .toList(),
  );
}
