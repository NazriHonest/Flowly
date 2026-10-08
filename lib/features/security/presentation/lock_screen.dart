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
  static const int _pinLength = 4;

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
    if (_busy) return;

    try {
      if (await _service.authenticateBiometric() && mounted) {
        widget.onUnlocked();
      }
    } catch (_) {
      // PIN remains available as the fallback.
    }
  }

  Future<void> _unlock() async {
    if (_pin.length != _pinLength || _busy) {
      return;
    }

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
      if (_pin.isEmpty) return;

      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = null;
      });

      return;
    }

    if (_pin.length >= _pinLength) {
      return;
    }

    setState(() {
      _pin += value;
      _error = null;
    });

    if (_pin.length == _pinLength) {
      _unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  color: AppColors.primary.withValues(alpha: 0.12),
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
                _busy
                    ? 'Checking your PIN...'
                    : 'Enter your PIN to unlock SpenFlo',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pinLength,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? AppColors.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 34,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _error == null
                      ? null
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const Spacer(),

              _Keypad(enabled: !_busy, onTap: _tap),

              const SizedBox(height: 12),

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
  const _Keypad({required this.onTap, required this.enabled});

  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
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
                  onTap: enabled ? () => onTap(key) : null,
                  child: Center(
                    child: key == 'delete'
                        ? Icon(
                            Icons.backspace_outlined,
                            color: enabled
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          )
                        : Text(
                            key,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: enabled
                                      ? null
                                      : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                ),
                          ),
                  ),
                ),
      ],
    );
  }
}
