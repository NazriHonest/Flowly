import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          state.maybeWhen(
            data: (items) {
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }

              final hasUnread = items.any((item) => !item.isRead);

              return PopupMenuButton<_NotificationAction>(
                tooltip: 'Notification options',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) async {
                  switch (action) {
                    case _NotificationAction.markAllRead:
                      await ref
                          .read(notificationListProvider.notifier)
                          .markAllRead();

                    case _NotificationAction.clearAll:
                      if (!context.mounted) return;

                      final confirmed = await showFlowlyConfirmation(
                        context,
                        title: 'Clear all notifications?',
                        message: 'This will remove all notifications from your notification history.',
                        confirmLabel: 'Clear all',
                      );

                      if (!confirmed) return;

                      await ref.read(notificationListProvider.notifier).clear();
                  }
                },
                itemBuilder: (context) => [
                  if (hasUnread)
                    const PopupMenuItem(
                      value: _NotificationAction.markAllRead,
                      child: _MenuAction(
                        icon: Icons.done_all_rounded,
                        label: 'Mark all as read',
                      ),
                    ),
                  const PopupMenuItem(
                    value: _NotificationAction.clearAll,
                    child: _MenuAction(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear all',
                      destructive: true,
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (error, _) => AppErrorState(
          title: 'Couldn’t load notifications',
          message: 'Please try again.',
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        data: (items) {
          final unreadCount = items.where((item) => !item.isRead).length;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationListProvider.notifier).refresh(),
            child: items.isEmpty
                ? _EmptyNotifications(
                    onRefresh: () =>
                        ref.read(notificationListProvider.notifier).refresh(),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _NotificationSummary(
                        totalCount: items.length,
                        unreadCount: unreadCount,
                      ),

                      const SizedBox(height: 24),

                      _SectionHeader(unreadCount: unreadCount),

                      const SizedBox(height: 12),

                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: const _DeleteBackground(),
                            onDismissed: (_) {
                              ref
                                  .read(notificationListProvider.notifier)
                                  .delete(item.id!);
                            },
                            child: _NotificationCard(
                              title: item.title,
                              body: item.body,
                              isRead: item.isRead,
                              onTap: item.isRead
                                  ? null
                                  : () => ref
                                        .read(notificationListProvider.notifier)
                                        .markRead(item.id!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

enum _NotificationAction { markAllRead, clearAll }

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.totalCount,
    required this.unreadCount,
  });

  final int totalCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final allRead = unreadCount == 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: allRead
            ? colors.surface
            : AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allRead
              ? colors.outlineVariant
              : AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: allRead
                  ? colors.surfaceContainerHighest
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              allRead
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_outlined,
              color: allRead ? colors.onSurfaceVariant : AppColors.primary,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allRead ? 'You’re all caught up' : '$unreadCount unread',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allRead
                      ? '$totalCount ${totalCount == 1 ? 'notification' : 'notifications'} in your history'
                      : '$totalCount ${totalCount == 1 ? 'notification' : 'notifications'} in total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (!allRead)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          'Recent',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (unreadCount > 0)
          Text(
            '$unreadCount unread',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.isRead,
    required this.onTap,
  });

  final String title;
  final String body;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: isRead
          ? colors.surface
          : AppColors.primary.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isRead
                  ? colors.outlineVariant
                  : AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isRead
                          ? colors.surfaceContainerHighest
                          : AppColors.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isRead
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                      color: isRead
                          ? colors.onSurfaceVariant
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),

                  if (!isRead)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),

                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'NEW',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),

                    if (!isRead) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Tap to mark as read',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.expense,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.only(right: 20),
      alignment: Alignment.centerRight,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline_rounded,
            color: AppColors.onPrimary,
            size: 23,
          ),
          SizedBox(height: 3),
          Text(
            'Delete',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.58,
          child: const AppEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You’re all caught up',
            message: 'Account, budget, transaction and review updates will appear here when there’s something you need to know.',
          ),
        ),
      ],
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
