import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../services/notification_inbox.dart';
import '../../services/notification_navigation.dart';

/// Lista de notificações da conta (o mesmo sino do portal web).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationInbox>().refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      context.read<NotificationInbox>().loadMore();
    }
  }

  Future<void> _open(AppNotification notification) async {
    final inbox = context.read<NotificationInbox>();
    await inbox.markAsRead(notification);

    if (NotificationNavigation.targetFor(notification.navigationData) ==
        NotificationTarget.inbox) {
      return;
    }

    NotificationNavigation.openFromData(notification.navigationData);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<NotificationInbox>();
    final items = inbox.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (inbox.unreadCount > 0)
            TextButton(
              onPressed: inbox.markAllAsRead,
              child: const Text('Marcar todas como lidas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: inbox.refresh,
        child: _buildBody(context, inbox, items),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationInbox inbox,
    List<AppNotification> items,
  ) {
    if (items.isEmpty && inbox.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.notifications_none,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              inbox.error ?? 'Nenhuma notificação por enquanto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + (inbox.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return NotificationTile(
          notification: items[index],
          onTap: () => _open(items[index]),
        );
      },
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = notification.createdAt;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        _iconFor(notification),
        color: notification.isUnread
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(
        notification.title,
        style: notification.isUnread
            ? const TextStyle(fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.body.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(notification.body),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      trailing: notification.isUnread
          ? Container(
              key: const ValueKey('unread-dot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  static IconData _iconFor(AppNotification notification) {
    if (notification.type == 'workshop-review-decided') {
      return notification.data['status'] == 'confirmed'
          ? Icons.verified
          : Icons.report_outlined;
    }

    return Icons.notifications_outlined;
  }
}

/// Sino da barra superior, com o número de não lidas.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationInbox>().unreadCount;

    return IconButton(
      tooltip: unread > 0 ? 'Notificações ($unread não lidas)' : 'Notificações',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
