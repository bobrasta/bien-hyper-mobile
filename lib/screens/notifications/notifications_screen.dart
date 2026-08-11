import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show notificationCountNotifier;
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/shimmer_box.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await NotificationService.instance.list(noCache: true);
      if (mounted) {
        setState(() { _notifications = data; _loading = false; });
        notificationCountNotifier.value = _unreadCount;
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load notifications.'; });
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    setState(() {
      _notifications = _notifications.map((n) => AppNotification(
        id: n.id, type: n.type, title: n.title, body: n.body,
        entityType: n.entityType, entityId: n.entityId,
        isRead: true, createdAt: n.createdAt,
      )).toList();
    });
    notificationCountNotifier.value = 0;
    try { await NotificationService.instance.markAllRead(); } catch (_) {}
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    setState(() {
      _notifications = _notifications.map((x) => x.id == n.id
          ? AppNotification(id: x.id, type: x.type, title: x.title, body: x.body,
              entityType: x.entityType, entityId: x.entityId,
              isRead: true, createdAt: x.createdAt)
          : x).toList();
    });
    notificationCountNotifier.value = _unreadCount;
    try { await NotificationService.instance.markRead(n.id); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.pal.border)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications', style: AppTheme.pageTitle),
              const SizedBox(height: 2),
              Text('Tap a notification to mark it as read.',
                  style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
            ])),
            if (_unreadCount > 0) ...[
              GestureDetector(
                onTap: _markAllRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.pal.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Mark all read',
                      style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: context.pal.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Symbols.refresh, size: 17, color: context.pal.textMute),
              ),
            ),
          ]),
        ),

        // Body
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return SingleChildScrollView(child: shimmerList(count: 10));
    }

    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.error_outline, size: 36, color: AppColors.coral),
        const SizedBox(height: 10),
        Text(_error!, style: AppTheme.bodySub.copyWith(color: AppColors.coral)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _load,
          child: Text('Retry', style: AppTheme.bodySm.copyWith(color: AppColors.teal)),
        ),
      ]));
    }

    if (_notifications.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.notifications_off, size: 40, color: context.pal.textDim),
        const SizedBox(height: 12),
        Text('No notifications', style: AppTheme.pageTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 6),
        Text("You're all caught up.", style: AppTheme.bodySub),
      ]));
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _notifications.length,
      itemBuilder: (context, i) => _NotificationRow(
        notification: _notifications[i],
        isLast: i == _notifications.length - 1,
        onTap: () => _markRead(_notifications[i]),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.isLast,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isLast;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
    NotificationType.serviceDue        => Symbols.build,
    NotificationType.ticketAssigned    => Symbols.confirmation_number,
    NotificationType.ticketUpdated     => Symbols.update,
    NotificationType.paymentOverdue    => Symbols.warning,
    NotificationType.warrantyExpiring  => Symbols.workspace_premium,
    NotificationType.dealUpdated       => Symbols.trending_up,
    NotificationType.leadFollowUp      => Symbols.hourglass_top,
    NotificationType.taskAssigned      => Symbols.assignment_ind,
    NotificationType.taskCompleted     => Symbols.task_alt,
    NotificationType.stockPullRequired => Symbols.inventory_2,
    NotificationType.leaveRequested    => Symbols.event_busy,
    NotificationType.leaveApproved     => Symbols.event_available,
    NotificationType.leaveRejected     => Symbols.event_busy,
    NotificationType.lateArrival       => Symbols.schedule,
    NotificationType.system            => Symbols.info,
  };

  Color get _color => switch (notification.type) {
    NotificationType.serviceDue        => AppColors.amber,
    NotificationType.ticketAssigned    => AppColors.teal,
    NotificationType.ticketUpdated     => AppColors.blue,
    NotificationType.paymentOverdue    => AppColors.coral,
    NotificationType.warrantyExpiring  => AppColors.amber,
    NotificationType.dealUpdated       => AppColors.violet,
    NotificationType.leadFollowUp      => AppColors.amber,
    NotificationType.taskAssigned      => AppColors.blue,
    NotificationType.taskCompleted     => AppColors.teal,
    NotificationType.stockPullRequired => AppColors.violet,
    NotificationType.leaveRequested    => AppColors.amber,
    NotificationType.leaveApproved     => AppColors.teal,
    NotificationType.leaveRejected     => AppColors.coral,
    NotificationType.lateArrival       => AppColors.amber,
    NotificationType.system            => AppColors.textMute,
  };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: unread ? context.pal.surface1 : Colors.transparent,
          border: isLast ? null : Border(
              bottom: BorderSide(color: context.pal.divider)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_icon, size: 18, color: _color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(notification.title,
                  style: AppTheme.bodyStrong.copyWith(
                    fontSize: 13,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                  ))),
              if (unread)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.teal, shape: BoxShape.circle),
                ),
            ]),
            const SizedBox(height: 3),
            Text(notification.body,
                style: AppTheme.bodySub.copyWith(fontSize: 12.5, height: 1.4),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(notification.type.label,
                    style: AppTheme.monoXs.copyWith(color: _color, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Text(notification.createdAt,
                  style: AppTheme.monoXs.copyWith(
                      color: context.pal.textDim, fontSize: 10.5)),
            ]),
          ])),
        ]),
      ),
    );
  }
}
