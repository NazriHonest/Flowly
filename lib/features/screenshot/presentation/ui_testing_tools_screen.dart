import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/data/security_service.dart';
import '../providers/screenshot_provider.dart';

class UiTestingToolsScreen extends ConsumerStatefulWidget {
  const UiTestingToolsScreen({super.key});

  @override
  ConsumerState<UiTestingToolsScreen> createState() => _UiTestingToolsScreenState();
}

class _UiTestingToolsScreenState extends ConsumerState<UiTestingToolsScreen>
    with WidgetsBindingObserver {
  final _security = SecurityService();
  bool _busy = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    debugPrint(
      'SpenFloScreenshot: ui_testing_tools_route_disposed '
      'screenshot_mode_unchanged=true',
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(screenshotControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('UI Testing Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Screenshot Mode temporarily allows Android screenshots for UI testing and design reviews. Screenshots may contain financial information.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            secondary: const Icon(Icons.screenshot_monitor_outlined),
            title: const Text('Enable Screenshot Mode'),
            subtitle: const Text(
              'Temporarily allow Android screenshots for UI testing and design reviews.',
            ),
            value: state.enabled,
            onChanged: _busy
                ? null
                : (enabled) => enabled ? _enable() : _disable(),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              state.enabled
                  ? Icons.check_circle_outline_rounded
                  : Icons.shield_outlined,
              color: state.enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: const Text('Screenshot Mode'),
            subtitle: Text(state.enabled ? 'Enabled' : 'Disabled'),
          ),
          if (state.enabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Screenshot Mode is enabled. Use your phone's Power + Volume Down buttons to take a screenshot.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Screenshots may contain financial information. Disable Screenshot Mode when finished.',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Screenshot Mode is temporary. It does not change balance visibility and is automatically disabled when SpenFlo leaves the foreground.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final securityEnabled = await _security.enabled;
      if (!mounted) return;
      if (!securityEnabled) {
        _message('Set up a SpenFlo PIN in Security before enabling Screenshot Mode.');
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Enable Screenshot Mode?'),
          content: const Text(
            'Screenshots can expose balances, accounts, and transactions. Only enable this mode in a private environment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Authenticate'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      if (!await _authenticate() || !mounted) {
        return;
      }
      if (!_foreground ||
          WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed) {
        await ref
            .read(screenshotControllerProvider.notifier)
            .disable(ScreenshotDisableReason.appBackgrounded);
        if (mounted) {
          _message(
            'Return to SpenFlo and authenticate again to enable Screenshot Mode.',
          );
        }
        return;
      }
      await ref
          .read(screenshotControllerProvider.notifier)
          .enableAfterAuthentication();
      if (mounted) _message('Screenshot Mode enabled temporarily.');
    } on PlatformException catch (error) {
      await ref
          .read(screenshotControllerProvider.notifier)
          .disable(ScreenshotDisableReason.activationFailed);
      if (mounted) _message(error.message ?? 'Could not enable Screenshot Mode.');
    } catch (error, stackTrace) {
      await ref
          .read(screenshotControllerProvider.notifier)
          .disable(ScreenshotDisableReason.activationFailed);
      _logAuthenticationFailure(error, stackTrace);
      if (mounted) _message('Could not enable Screenshot Mode.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _authenticate() async {
    if (await _security.biometricEnabled()) {
      try {
        if (await _security.authenticateBiometric()) return true;
      } catch (_) {
        // PIN remains the authenticated fallback.
      }
    }
    if (!mounted || !_foreground) return false;
    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinVerificationDialog(
        security: _security,
      ),
    );
    return authenticated == true;
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      final protected = await ref
          .read(screenshotControllerProvider.notifier)
          .disable(ScreenshotDisableReason.userDisabled);
      if (mounted) {
        _message(
          protected
              ? 'Screenshot Mode disabled.'
              : 'Could not restore screenshot protection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PinVerificationDialog extends StatefulWidget {
  const _PinVerificationDialog({required this.security});

  final SecurityService security;

  @override
  State<_PinVerificationDialog> createState() =>
      _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _controller.text;
    if (pin.length < 4) {
      setState(() => _error = 'Enter your existing SpenFlo PIN.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final valid = await widget.security.verifyPin(pin);
      if (!mounted) return;
      if (valid) {
        Navigator.of(context).pop(true);
        return;
      }
      final remaining = await widget.security.lockoutRemaining();
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _submitting = false;
        _error = remaining == null
            ? 'Incorrect PIN. Try again.'
            : 'Too many attempts. Try again in ${remaining.inSeconds + 1}s.';
      });
    } catch (error, stackTrace) {
      _logAuthenticationFailure(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'PIN verification could not be completed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm your PIN'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      enabled: !_submitting,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 12,
      decoration: InputDecoration(
        labelText: 'PIN',
        counterText: '',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Confirm'),
      ),
    ],
  );
}

void _logAuthenticationFailure(Object error, StackTrace stackTrace) {
  debugPrint(
    'Screenshot authentication failed: ${error.runtimeType}',
  );
  debugPrintStack(stackTrace: stackTrace);
}
