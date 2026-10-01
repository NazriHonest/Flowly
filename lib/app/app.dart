import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/sms_detection/providers/sms_live_provider.dart';
import 'router.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/security/data/security_service.dart';
import '../features/security/presentation/lock_screen.dart';
import '../core/theme/app_colors.dart';

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
    if (state == AppLifecycleState.resumed) _evaluateResumeLock();
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
      title: 'Flowly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
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
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 18),
          const Text('Flowly', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.6)),
          const SizedBox(height: 6),
          const Text('Money, made clear', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 34),
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
        ]),
      ),
    ),
  );
}
