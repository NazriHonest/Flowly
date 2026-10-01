import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final state = r.watch(notificationListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () =>
                r.read(notificationListProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Clear notifications',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => r.read(notificationListProvider.notifier).clear(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingList(),
        error: (e, _) => AppErrorState(
          title: 'Couldn’t load notifications',
          message: 'Please try again.',
          onRetry: () => r.invalidate(notificationListProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: 'Important account, budget, and review updates will appear here.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: items
                    .map(
                      (item) => Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: const ColoredBox(
                          color: AppColors.expense,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 20),
                              child: Icon(Icons.delete, color: AppColors.onPrimary),
                            ),
                          ),
                        ),
                        onDismissed: (_) => r
                            .read(notificationListProvider.notifier)
                            .delete(item.id!),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 9),
                          color: item.isRead
                              ? null
                              : AppColors.primary.withValues(alpha: .06),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: .12,
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(item.title),
                            subtitle: Text(item.body),
                            trailing: item.isRead
                                ? null
                                : const Icon(Icons.circle, size: 10),
                            onTap: () => r
                                .read(notificationListProvider.notifier)
                                .markRead(item.id!),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
