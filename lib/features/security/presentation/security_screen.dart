import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/security_service.dart';
import '../../../core/widgets/app_widgets.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final service = SecurityService();
  bool? enabled;
  int timeout = 0;
  bool biometric = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    enabled = await service.enabled;
    timeout = await service.timeoutMinutes();
    if (mounted) setState(() {});
  }

  Future<void> _pinFlow({bool disabling = false, bool changing = false}) async {
    if (changing) {
      final current = await _pinSheet('Enter current PIN');
      if (current == null) return;
      if (!await service.verifyPin(current)) {
        if (mounted) _notice('Incorrect PIN. Please try again.');
        return;
      }
    }
    final pin = await _pinSheet(
      disabling ? 'Enter current PIN' : changing ? 'Create a new PIN' : 'Create your PIN',
    );
    if (pin == null) return;
    if (disabling && !await service.verifyPin(pin)) {
      if (mounted) _notice('Incorrect PIN. Please try again.');
      return;
    }
    if (!disabling) {
      final confirmation = await _pinSheet('Confirm your PIN');
      if (confirmation == null) return;
      if (confirmation != pin) {
        if (mounted) _notice('PINs don’t match. Please try again.');
        return;
      }
    }
    try {
      if (disabling) {
        await service.disable();
      } else {
        await service.setPin(pin);
      }
      await _load();
    } on ArgumentError {
      if (mounted) _notice('PIN must contain 4–12 digits.');
    }
  }

  Future<String?> _pinSheet(String title) async {
    var pin = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('Choose a secure numeric PIN for Flowly.'),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pin.length
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children:
                      [
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6',
                            '7',
                            '8',
                            '9',
                            '',
                            '0',
                            '⌫',
                          ]
                          .map(
                            (value) => value.isEmpty
                                ? const SizedBox()
                                : TextButton(
                                    onPressed: () {
                                      if (value == '⌫') {
                                        update(
                                          () => pin = pin.isEmpty
                                              ? ''
                                              : pin.substring(
                                                  0,
                                                  pin.length - 1,
                                                ),
                                        );
                                      } else if (pin.length < 12) {
                                        update(() => pin += value);
                                      }
                                    },
                                    child: Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: pin.length < 4
                        ? null
                        : () => Navigator.pop(sheet, pin),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security')),
    body: enabled == null
        ? const AppLoadingList(count: 4)
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PIN lock',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              enabled!
                                  ? 'Your app is protected'
                                  : 'Protect Flowly with a PIN',
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled!,
                        onChanged: (value) => _pinFlow(disabling: !value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _Label('APP LOCK'),
              _SettingsCard(
                children: [
                  _Row(
                    icon: Icons.key_outlined,
                    title: 'Change PIN',
                    subtitle: 'Update your app lock PIN',
                    enabled: enabled!,
                    onTap: () => _pinFlow(changing: true),
                  ),
                  _Row(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric unlock',
                    subtitle: biometric ? 'Enabled' : 'Use fingerprint or face',
                    enabled: enabled!,
                    trailing: Switch(
                      value: biometric,
                      onChanged: enabled!
                          ? (value) async {
                              if (value) {
                                final ok = await service
                                    .authenticateBiometric();
                                if (mounted) setState(() => biometric = ok);
                              } else {
                                setState(() => biometric = false);
                              }
                            }
                          : null,
                    ),
                  ),
                  _Row(
                    icon: Icons.timer_outlined,
                    title: 'Lock timeout',
                    subtitle: timeout == 0 ? 'Immediately' : '$timeout minutes',
                    enabled: enabled!,
                    onTap: _timeoutSheet,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Label('SECURITY STATUS'),
              Card(
                color: AppColors.primary.withValues(alpha: .10),
                child: const ListTile(
                  leading: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Your PIN is stored securely on this device',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Flowly never stores your PIN in plain text.'),
                ),
              ),
              if (enabled!) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _pinFlow(disabling: true),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Disable PIN lock'),
                ),
              ],
            ],
          ),
  );
  Future<void> _timeoutSheet() async => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lock timeout',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            ...[0, 1, 5, 15].map(
              (value) => RadioListTile<int>(
                value: value,
                groupValue: timeout,
                title: Text(value == 0 ? 'Immediately' : '$value minutes'),
                onChanged: (choice) async {
                  await service.setTimeoutMinutes(choice!);
                  if (mounted) setState(() => timeout = choice);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
    child: Text(
      value,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(child: Column(children: children));
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String title, subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    onTap: onTap,
    leading: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
  );
}
