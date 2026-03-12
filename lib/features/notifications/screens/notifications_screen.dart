import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum NotificationCategory { payment, maintenance, announcement, forum, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: _parseCategory(json['type'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['read_at'] != null,
    );
  }

  static NotificationCategory _parseCategory(String? value) {
    switch (value) {
      case 'payment':
        return NotificationCategory.payment;
      case 'maintenance':
        return NotificationCategory.maintenance;
      case 'announcement':
        return NotificationCategory.announcement;
      case 'forum':
        return NotificationCategory.forum;
      default:
        return NotificationCategory.system;
    }
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _notificationsProvider =
    StateNotifierProvider<_NotificationsNotifier, AsyncValue<List<AppNotification>>>(
  (ref) => _NotificationsNotifier(ref),
);

class _NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  int _page = 1;
  bool _hasMore = true;

  _NotificationsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.getNotifications(page: 1, limit: 20);
      final data = response.data;
      final innerData = data['data'];
      final items = innerData is Map ? innerData['data'] : innerData;
      final list = (items as List?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <AppNotification>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.getNotifications(page: _page, limit: 20);
      final innerData = response.data['data'];
      final items = innerData is Map ? innerData['data'] : innerData;
      final list = (items as List?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <AppNotification>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data([...current, ...list]);
    } catch (_) {
      _page--;
    }
  }

  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    );
    try {
      final api = _ref.read(apiClientProvider);
      await api.markNotificationRead(id);
    } catch (_) {
      // Revert on failure
      state = AsyncValue.data(
        current.map((n) => n.id == id ? n.copyWith(isRead: false) : n).toList(),
      );
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull ?? [];
    final unreadIds = current.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    state = AsyncValue.data(
      current.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      final api = _ref.read(apiClientProvider);
      for (final id in unreadIds) {
        await api.markNotificationRead(id);
      }
    } catch (_) {
      // best-effort; keep the optimistic update
    }
  }

  void dismiss(String id) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((n) => n.id != id).toList());
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: () {
              ref.read(_notificationsProvider.notifier).markAllAsRead();
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const _ShimmerList(),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(_notificationsProvider.notifier).fetch(),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(_notificationsProvider.notifier).fetch(),
            child: _NotificationList(notifications: notifications),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification list with infinite scroll
// ---------------------------------------------------------------------------

class _NotificationList extends ConsumerStatefulWidget {
  final List<AppNotification> notifications;
  const _NotificationList({required this.notifications});

  @override
  ConsumerState<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends ConsumerState<_NotificationList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(_notificationsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.notifications.length,
      itemBuilder: (context, index) {
        final notification = widget.notifications[index];
        return _NotificationTile(
          notification: notification,
          onDismissed: () {
            ref.read(_notificationsProvider.notifier).dismiss(notification.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification dismissed'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onMarkAsRead: () {
            ref.read(_notificationsProvider.notifier).markAsRead(notification.id);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single notification tile with swipe
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismissed;
  final VoidCallback onMarkAsRead;

  const _NotificationTile({
    required this.notification,
    required this.onDismissed,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: AppColors.primary.withValues(alpha: 0.15),
        child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onMarkAsRead();
          return false; // don't remove, just mark as read
        }
        return true; // dismiss
      },
      onDismissed: (_) => onDismissed(),
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : AppColors.primary.withValues(alpha: 0.04),
        child: ListTile(
          leading: _CategoryIcon(category: notification.category),
          title: Text(
            notification.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notification.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimeAgo(notification.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: () {
            if (!notification.isRead) onMarkAsRead();
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category icon
// ---------------------------------------------------------------------------

class _CategoryIcon extends StatelessWidget {
  final NotificationCategory category;
  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (category) {
      NotificationCategory.payment => (Icons.payment_rounded, AppColors.accent),
      NotificationCategory.maintenance => (Icons.build_rounded, AppColors.warning),
      NotificationCategory.announcement => (Icons.campaign_rounded, AppColors.info),
      NotificationCategory.forum => (Icons.forum_rounded, AppColors.primary),
      NotificationCategory.system => (Icons.settings_rounded, AppColors.textSecondary),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you receive notifications, they will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading skeleton
// ---------------------------------------------------------------------------

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 8,
        itemBuilder: (_, __) => const _ShimmerNotificationTile(),
      ),
    );
  }
}

class _ShimmerNotificationTile extends StatelessWidget {
  const _ShimmerNotificationTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  if (diff.inDays < 30) {
    return '${(diff.inDays / 7).floor()}w ago';
  }
  if (diff.inDays < 365) {
    return '${(diff.inDays / 30).floor()}mo ago';
  }
  return '${(diff.inDays / 365).floor()}y ago';
}
