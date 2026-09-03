import 'dart:async';
import 'package:local_notifier/local_notifier.dart';
import '../main.dart' show notificationCountNotifier, refreshPermissions;
import 'auth_service.dart';
import 'email_service.dart';
import 'notification_service.dart';
import 'staff_service.dart';
import 'ticket_service.dart';

class BackgroundSync {
  BackgroundSync._();
  static final instance = BackgroundSync._();

  Timer? _timer;
  bool  _initialized   = false;
  int   _lastNotif     = 0;
  int   _lastEmail     = 0;
  int   _lastOpenCount = 0;
  int   _lastMyCount   = 0;
  int?  _userId;

  Future<void> start() async {
    if (_timer != null) return;
    _userId = await _resolveUserId();
    await _poll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  Future<int?> _resolveUserId() async {
    try {
      final p = await AuthService.instance.getProfile();
      return (p?['id'] as num?)?.toInt();
    } catch (_) { return null; }
  }

  Future<void> _poll() async {
    await Future.wait([
      _pollNotifications(), _pollEmail(), _pollTickets(),
      StaffService.instance.poll(), _pollPermissions(),
    ]);
    _initialized = true;
  }

  // A role's permissions (or an individual override) can change while this
  // user is mid-session — e.g. a director editing the Role Builder, or an
  // admin promoting this account. userPermissionsNotifier previously only
  // refreshed on login/app-startup, so a change made server-side never
  // reached an already-open session until the next login.
  Future<void> _pollPermissions() async {
    try {
      await refreshPermissions();
    } catch (_) {}
  }

  Future<void> _pollNotifications() async {
    try {
      final items = await NotificationService.instance.list(noCache: true);
      final count = items.where((n) => !n.isRead).length;
      notificationCountNotifier.value = count;
      if (_initialized && count > _lastNotif) {
        _toast('New notification',
            'You have $count unread notification${count == 1 ? '' : 's'}');
      }
      _lastNotif = count;
    } catch (_) {}
  }

  Future<void> _pollEmail() async {
    try {
      final count = await EmailService.instance.unreadCount(noCache: true);
      if (_initialized && count > _lastEmail) {
        _toast('New email', '$count unread email${count == 1 ? '' : 's'} in your inbox');
      }
      _lastEmail = count;
    } catch (_) {}
  }

  Future<void> _pollTickets() async {
    try {
      final open = await TicketService.instance.list(status: 'open', noCache: true);
      final count = open.length;
      if (_initialized && count > _lastOpenCount) {
        final delta = count - _lastOpenCount;
        _toast('New service ticket', '$delta new open ticket${delta == 1 ? '' : 's'}');
      }
      _lastOpenCount = count;
    } catch (_) {}

    if (_userId != null) {
      try {
        final mine = await TicketService.instance.list(
          status: 'open', assignedTo: _userId, noCache: true,
        );
        final count = mine.length;
        if (_initialized && count > _lastMyCount) {
          final delta = count - _lastMyCount;
          _toast('Task assigned to you',
              '$delta new ticket${delta == 1 ? '' : 's'} assigned to you');
        }
        _lastMyCount = count;
      } catch (_) {}
    }
  }

  void _toast(String title, String body) {
    LocalNotification(
      identifier: 'hm_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
    ).show();
  }
}
