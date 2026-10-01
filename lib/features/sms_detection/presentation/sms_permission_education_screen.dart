import 'package:flutter/material.dart';

import '../data/sms_permission_bridge.dart';
import '../providers/automatic_detection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';

class SmsPermissionEducationScreen extends ConsumerStatefulWidget {
  const SmsPermissionEducationScreen({super.key});
  @override
  ConsumerState<SmsPermissionEducationScreen> createState() =>
      _SmsPermissionEducationScreenState();
}

class _SmsPermissionEducationScreenState
    extends ConsumerState<SmsPermissionEducationScreen> {
  bool loading = false;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Automatic transaction detection')),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: FlowlyIcon(icon: Icons.privacy_tip_outlined, size: 76)),
          const SizedBox(height: 20),
          Text(
            'Your financial messages stay private.',
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Flowly processes supported financial messages on this device. You remain in control at every step.',
          ),
          const SizedBox(height: 20),
          const FlowlySurface(child: Column(children: [
            _PrivacyPoint(icon: Icons.phone_android_outlined, title: 'Processed on your device', detail: 'Message text never leaves your phone.'),
            Divider(height: 24),
            _PrivacyPoint(icon: Icons.delete_outline, title: 'Raw messages are transient', detail: 'Only normalized financial details are kept.'),
            Divider(height: 24),
            _PrivacyPoint(icon: Icons.tune_outlined, title: 'Always optional', detail: 'Manual tracking works without this permission.'),
          ])),
          const Spacer(),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: loading
                ? null
                : ref.watch(automaticDetectionProvider)
                ? () async { await ref.read(automaticDetectionProvider.notifier).setEnabled(false); if (mounted) Navigator.pop(c, false); }
                : () async {
                    setState(() => loading = true);
                    final bridge = const SmsPermissionBridge();
                    final granted = await bridge.request();
                    if (!mounted) return;
                    if (granted) {
                      await ref.read(automaticDetectionProvider.notifier).setEnabled(true);
                      if (mounted) Navigator.pop(context, true);
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted ? 'Automatic detection permission enabled' : 'Permission was not granted. Manual tracking remains available.',
                        ),
                      ),
                    );
                    if (mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Permission not granted'),
                          content: const Text('You can continue manually, or enable SMS access from Android app settings.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Continue manually')),
                            FilledButton(onPressed: () async { await bridge.openAppSettings(); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('Open settings')),
                          ],
                        ),
                      );
                    }
                    setState(() => loading = false);
                  },
            child: Text(
              loading ? 'Requesting permission…' : 'Enable automatic detection',
            ),
          )),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Row(children: [
    FlowlyIcon(icon: icon, size: 38),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(detail, style: Theme.of(context).textTheme.bodySmall)])),
  ]);
}
