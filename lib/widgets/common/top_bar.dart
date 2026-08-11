import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show themeNotifier, authTokenNotifier, userNameNotifier, nameInitials, notificationCountNotifier;
import '../../models/notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import 'avatar_widget.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key, this.onMenuPressed, this.onViewAllNotifications});
  final VoidCallback? onMenuPressed;
  final VoidCallback? onViewAllNotifications;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  // Overlay portal controller + layer link for anchored dropdown
  final _overlayController = OverlayPortalController();
  final _layerLink          = LayerLink();

  List<AppNotification> _notifications        = [];
  bool                  _loadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_loadingNotifications) return;
    setState(() => _loadingNotifications = true);
    try {
      final data = await NotificationService.instance.list();
      if (mounted) {
        setState(() { _notifications = data; _loadingNotifications = false; });
        notificationCountNotifier.value = _unreadCount;
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNotifications = false);
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

  Future<void> _markRead(int id) async {
    setState(() {
      _notifications = _notifications.map((n) => n.id == id
          ? AppNotification(
              id: n.id, type: n.type, title: n.title, body: n.body,
              entityType: n.entityType, entityId: n.entityId,
              isRead: true, createdAt: n.createdAt)
          : n).toList();
    });
    notificationCountNotifier.value = _unreadCount;
    try { await NotificationService.instance.markRead(id); } catch (_) {}
  }

  Future<void> _logout() async {
    final token = authTokenNotifier.value;
    if (token != null) await AuthService.instance.logout(token);
    authTokenNotifier.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.onMenuPressed != null;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.pal.topbarBg,
        border: Border(bottom: BorderSide(color: context.pal.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Hamburger (mobile only) ─────────────────────────────────────────
          if (isMobile) ...[
            GestureDetector(
              onTap: widget.onMenuPressed,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                child: Icon(Symbols.menu, size: 22, color: context.pal.textMute),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // ── Brand mark ──────────────────────────────────────────────────────
          _BrandMark(),

          // ── Desktop extras ──────────────────────────────────────────────────
          if (!isMobile) ...[
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: context.pal.border),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORKSPACE', style: AppTheme.monoXs),
                Text('Hypermed Health Care',
                    style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                height: 34,
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.pal.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text('Search machines, hospitals, tickets…',
                      style: AppTheme.bodySm.copyWith(color: context.pal.textDim))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.pal.surface3,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: context.pal.border),
                    ),
                    child: Text('⌘K', style: AppTheme.monoXs),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            _IconBtn(icon: Symbols.help_outline),
            const SizedBox(width: 4),
            ValueListenableBuilder<AppThemeMode>(
              valueListenable: themeNotifier,
              builder: (_, mode, _) => GestureDetector(
                onTap: () => themeNotifier.value = switch (mode) {
                  AppThemeMode.dark    => AppThemeMode.light,
                  AppThemeMode.light   => AppThemeMode.neutral,
                  AppThemeMode.neutral => AppThemeMode.dark,
                },
                child: _IconBtn(
                  icon: switch (mode) {
                    AppThemeMode.dark    => Symbols.light_mode,
                    AppThemeMode.light   => Symbols.tonality,
                    AppThemeMode.neutral => Symbols.dark_mode,
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
          ] else ...[
            const Spacer(),
            _IconBtn(icon: Symbols.search),
            const SizedBox(width: 4),
          ],

          // ── Notification bell — OverlayPortal dropdown ──────────────────────
          CompositedTransformTarget(
            link: _layerLink,
            child: OverlayPortal(
              controller: _overlayController,
              // The overlay renders above the entire widget tree — no layout impact
              overlayChildBuilder: (ctx) => GestureDetector(
                // Tap outside → close
                behavior: HitTestBehavior.translucent,
                onTap: _overlayController.hide,
                child: Stack(children: [
                  Positioned.fill(child: const ColoredBox(color: Colors.transparent)),
                  CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomRight,
                    followerAnchor: Alignment.topRight,
                    child: GestureDetector(
                      // Prevent taps inside panel from closing it
                      onTap: () {},
                      child: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 380,
                          child: _NotificationPanel(
                            notifications: _notifications,
                            unreadCount: _unreadCount,
                            onMarkAllRead: () {
                              _markAllRead();
                              setState(() {});
                            },
                            onMarkRead: (id) {
                              _markRead(id);
                              setState(() {});
                            },
                            onClose: _overlayController.hide,
                            onViewAll: widget.onViewAllNotifications == null ? null : () {
                              _overlayController.hide();
                              widget.onViewAllNotifications!();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              child: GestureDetector(
                onTap: () => setState(() {
                  if (_overlayController.isShowing) {
                    _overlayController.hide();
                  } else {
                    _overlayController.show();
                  }
                }),
                child: Stack(children: [
                  _IconBtn(
                    icon: Symbols.notifications,
                    active: _overlayController.isShowing,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: notificationCountNotifier,
                    builder: (_, count, _) => count > 0
                        ? Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.pal.topbarBg, width: 1.5),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ),

          const SizedBox(width: 8),
          ValueListenableBuilder<String>(
            valueListenable: userNameNotifier,
            builder: (_, name, _) => AvatarWidget(
              initials: nameInitials(name),
              size: 30,
              variant: AvatarVariant.teal,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _logout,
            child: _IconBtn(icon: Symbols.logout),
          ),
        ],
      ),
    );
  }
}

// ── Notification Panel ─────────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.notifications,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onMarkRead,
    required this.onClose,
    this.onViewAll,
  });
  final List<AppNotification> notifications;
  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final ValueChanged<int> onMarkRead;
  final VoidCallback onClose;
  final VoidCallback? onViewAll;

  IconData _icon(NotificationType t) => switch (t) {
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

  Color _color(NotificationType t) => switch (t) {
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
    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0x60000000), blurRadius: 40, offset: Offset(0, 12)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Text('Notifications', style: AppTheme.bodyStrong),
            const SizedBox(width: 8),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.coralSoft, borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$unreadCount', style: AppTheme.bodySub.copyWith(
                  color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (unreadCount > 0) ...[
              GestureDetector(
                onTap: onMarkAllRead,
                child: Text('Mark all read', style: AppTheme.bodySub.copyWith(
                  color: AppColors.teal, fontSize: 12)),
              ),
              const SizedBox(width: 12),
            ],
            GestureDetector(
              onTap: onClose,
              child: Icon(Symbols.close, size: 16, color: context.pal.textDim),
            ),
          ]),
        ),
        // List
        Flexible(
          child: notifications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.notifications_off, size: 32, color: context.pal.textDim),
                    const SizedBox(height: 8),
                    Text('No notifications', style: AppTheme.bodySub),
                  ])),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    final color = _color(n.type);
                    return GestureDetector(
                      onTap: () => onMarkRead(n.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: n.isRead ? Colors.transparent : context.pal.surface2,
                          border: i < notifications.length - 1
                            ? Border(bottom: BorderSide(color: context.pal.divider))
                            : null,
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_icon(n.type), size: 16, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(n.title, style: AppTheme.bodyStrong.copyWith(
                                fontSize: 12.5,
                                fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
                              ))),
                              if (!n.isRead)
                                Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.teal, shape: BoxShape.circle),
                                ),
                            ]),
                            const SizedBox(height: 3),
                            Text(n.body,
                              style: AppTheme.bodySub.copyWith(fontSize: 11.5, height: 1.4),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(n.createdAt, style: AppTheme.monoXs.copyWith(
                              color: context.pal.textDim, fontSize: 10.5)),
                          ])),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        // Footer
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.pal.border)),
            ),
            child: Center(
              child: Text('View all notifications',
                style: AppTheme.bodySub.copyWith(
                  color: onViewAll != null ? AppColors.teal : context.pal.textDim,
                  fontSize: 12.5,
                )),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/hypermed_logo.png',
    height: 28, fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, this.active = false});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
      color: active ? context.pal.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 20, color: active ? context.pal.text : context.pal.textMute),
  );
}
