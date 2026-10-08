import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/sms_detection/providers/sms_live_provider.dart';
import '../features/sms_detection/providers/automatic_detection_provider.dart';
import '../features/transactions/providers/transaction_provider.dart';
import '../features/transactions/providers/transfer_candidate_provider.dart';
import 'router.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/security/data/security_service.dart';
import '../features/security/presentation/lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlowlyApp extends ConsumerStatefulWidget {
  const FlowlyApp({super.key});
  @override
  ConsumerState<FlowlyApp> createState() => _FlowlyAppState();
}

class _FlowlyAppState extends ConsumerState<FlowlyApp>
    with WidgetsBindingObserver {
  bool? completed;
  bool locked = false;
  DateTime? backgroundedAt;
  final security = SecurityService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => completed = p.getBool('onboardingCompleted') ?? false);
        _lockOnLaunch();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockOnLaunch() async {
    if (await security.enabled && mounted) setState(() => locked = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      backgroundedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) _handleResume();
  }

  Future<void> _handleResume() async {
    await _evaluateResumeLock();
    final enabled = await ref
        .read(automaticDetectionProvider.notifier)
        .reconcileOnResume();
    if (!enabled) return;
    await ref.read(transactionListProvider.notifier).refresh();
    await ref.read(pendingSmsTransferListProvider.notifier).refresh();
  }

  Future<void> _evaluateResumeLock() async {
    final started = backgroundedAt;
    backgroundedAt = null;
    if (started == null || !await security.enabled) return;
    final timeout = await security.timeoutMinutes();
    if (timeout == 0 ||
        DateTime.now().difference(started).inMinutes >= timeout) {
      if (mounted) setState(() => locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(smsLiveListenerProvider);
    return MaterialApp(
      title: 'SpenFlo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) {
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: completed == null
          ? const _FlowlySplash()
          : completed!
          ? (locked
                ? LockScreen(onUnlocked: () => setState(() => locked = false))
                : const AppRouter())
          : OnboardingScreen(
              onComplete: () => setState(() => completed = true),
            ),
    );
  }
}

class _FlowlySplash extends StatelessWidget {
  const _FlowlySplash();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF011711)
        : const Color(0xFFFDFFFE);
    final asset = dark
        ? 'assets/logo_images/Splash logo dark.png'
        : 'assets/logo_images/splash logo light.png';

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'SpenFlo. Know where your money goes.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
