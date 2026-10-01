import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: Row(
      children: [
        Text(
          title,
          style: Theme.of(c).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        ?action,
      ],
    ),
  );
}

/// A consistent elevated-content surface for forms, settings and detail screens.
class FlowlySurface extends StatelessWidget {
  const FlowlySurface({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    ),
  );
}

class FlowlyIcon extends StatelessWidget {
  const FlowlyIcon({super.key, required this.icon, this.color = AppColors.primary, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .32)),
    child: Icon(icon, color: color, size: size * .48),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? title, actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          if (title != null)
            Text(
              title!,
              style: Theme.of(c).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          if (title != null) const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final String title, message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.error_outline_rounded,
    title: title,
    message: message,
    actionLabel: 'Try Again',
    onAction: onRetry,
  );
}

class AppLoadingList extends StatelessWidget {
  const AppLoadingList({super.key, this.count = 5});
  final int count;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Container(
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .4),
      ),
    ),
  );
}

/// The shared, deliberately compact feedback language used across Flowly.
class FlowlyConfirmDialog extends StatelessWidget {
  const FlowlyConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });
  final String title, message, confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.onError : scheme.onPrimary;
    final background = destructive ? scheme.error : scheme.primary;
    return AlertDialog(
      icon: Icon(
        destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
        color: destructive ? scheme.error : scheme.primary,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: background, foregroundColor: foreground),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

Future<bool> showFlowlyConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => FlowlyConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    ) ??
    false;

class FlowlySection extends StatelessWidget {
  const FlowlySection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
      const SizedBox(height: 8),
      Card(child: Column(children: children)),
    ]),
  );
}

void showFlowlySnackBar(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? scheme.errorContainer : scheme.inverseSurface,
    content: Text(message, style: TextStyle(color: error ? scheme.onErrorContainer : scheme.onInverseSurface)),
  ));
}
