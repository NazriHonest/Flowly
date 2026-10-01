import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _service = SecurityService();
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    try {
      if (await _service.authenticateBiometric() && mounted) {
        widget.onUnlocked();
      }
    } catch (_) {}
  }

  Future<void> _unlock() async {
    if (_pin.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final valid = await _service.verifyPin(_pin);
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _pin = '';
      _error = 'Incorrect PIN. Try again.';
    });
  }

  void _tap(String value) {
    if (_busy) return;
    if (value == 'delete') {
      setState(
        () => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1),
      );
    } else if (_pin.length < 12) {
      setState(() {
        _pin += value;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Welcome back',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Enter your PIN to unlock Flowly',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? AppColors.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 24,
                child: Center(
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                ),
              ),
              const Spacer(),
              _Keypad(onTap: _tap),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _pin.length < 4 || _busy ? null : _unlock,
                  child: Text(_busy ? 'Unlocking...' : 'Unlock'),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _tryBiometric,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Use biometrics'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.55,
    children: [
      for (final key in [
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
        'delete',
      ])
        key.isEmpty
            ? const SizedBox()
            : InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () => onTap(key),
                child: Center(
                  child: key == 'delete'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(
                          key,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
    ],
  );
}
