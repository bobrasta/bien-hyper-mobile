import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'screens/auth/login_screen.dart';
import 'screens/trial/trial_expired_screen.dart' show TrialExpiredScreen, TrialPendingScreen;
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/trial_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_shell.dart';

/// Global auth token — null means not logged in, non-null means authenticated.
late final ValueNotifier<String?> authTokenNotifier;

/// Global logged-in user's display name — updated on login and profile save.
final userNameNotifier = ValueNotifier<String>('');

/// Global logged-in user's id — used for "is this assigned to me" checks
/// (e.g. the service-ticket acknowledge button). Null until login/profile
/// resolves it.
final userIdNotifier = ValueNotifier<int?>(null);

/// Global trial status — checked once on startup.
late final ValueNotifier<TrialStatus> trialNotifier;

/// Global logged-in user's role — drives sidebar filtering and screen guards.
final userRoleNotifier = ValueNotifier<String>('');

/// Global effective permissions (key -> scope) — see EffectivePermissionResolver
/// on the backend. Refreshed on login and app startup, same lifecycle as
/// [userRoleNotifier]. Every data-bearing call this only gates client-side
/// rendering with is independently re-checked server-side — a stale local
/// copy is a UI-convenience risk only, never a security boundary.
final userPermissionsNotifier = ValueNotifier<Map<String, String>>({});

/// Whether the current user's effective permissions include [key].
bool can(String key) => userPermissionsNotifier.value.containsKey(key);

/// The scope ('none'|'masked'|'own'|'team'|'all') the current user holds
/// [key] at, or null if they don't hold it at all.
String? scopeOf(String key) => userPermissionsNotifier.value[key];

Future<void> refreshPermissions() async {
  try {
    final perms = await PermissionService.instance.fetchMine();
    userPermissionsNotifier.value = {for (final p in perms) p.key: p.scope};
  } catch (_) {
    // Non-fatal — screens gated by can() just keep whatever they last had
    // until the next successful fetch (e.g. next login).
  }
}

/// Unread notification count — updated by BackgroundSync; drives the bell badge.
final notificationCountNotifier = ValueNotifier<int>(0);

const _screenKeys = [
  'dashboard', 'approvals', 'machines', 'detail', 'hospitals', 'service',
  'inventory', 'finance', 'staff', 'my_leave', 'reports', 'settings',
  'sales', 'customers', 'revenue', 'email', 'hr_approvals', 'hr_settings',
  'hr_dashboard', 'hr_directory', 'hr_recruitment', 'hr_leave_calendar',
  'hr_attendance', 'hr_payroll', 'hr_reports', 'notifications', 'delegations',
];

/// Returns the set of screen keys accessible for the current user. Primarily
/// driven by their effective `screens.*` permissions (see PermissionSeeder's
/// seedScreenPermissions() on the backend) — so a brand-new role built via
/// the Role Builder can see relevant screens immediately, with no Flutter
/// redeploy needed. Falls back to the pre-Phase-1 hardcoded table below only
/// when the user holds none of those permissions at all (e.g. the
/// permissions fetch failed, or they're on an older backend that predates
/// this seed step) — [role] is only consulted in that fallback path.
Set<String>? allowedScreenKeys(String role) {
  final perms = userPermissionsNotifier.value;
  if (perms.containsKey('authority.admin_tier')) return null; // full access
  final fromPermissions = _screenKeys.where((k) => perms.containsKey('screens.$k')).toSet();
  if (fromPermissions.isNotEmpty) return fromPermissions;
  return _legacyAllowedScreenKeys(role);
}

Set<String>? _legacyAllowedScreenKeys(String role) => switch (role) {
  'super_admin' || 'admin' => null,
  'cto'            => {'dashboard', 'approvals', 'machines', 'detail', 'hospitals', 'service', 'inventory', 'finance', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  // No 'staff' or 'inventory' — a technician does the repair work, not
  // staff task assignment or stock management.
  'technician'     => {'dashboard', 'machines', 'detail', 'hospitals', 'service', 'my_leave', 'reports', 'settings', 'notifications'},
  'team_leader'    => {'dashboard', 'approvals', 'machines', 'detail', 'hospitals', 'service', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  'sales_manager' || 'sales' => {'dashboard', 'machines', 'detail', 'sales', 'customers', 'revenue', 'email', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  'finance_manager' || 'finance' => {'dashboard', 'revenue', 'finance', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  'cs'             => {'dashboard', 'customers', 'service', 'email', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  'storekeeper'    => {'dashboard', 'inventory', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  // HR does not get the operational 'staff' (task-assignment board) key —
  // that's Operations' job. The hr_* keys below are HR's own dedicated
  // section (dashboard, personal-info directory, recruitment, leave
  // calendar, attendance, payroll, reports).
  'hr'             => {
    'dashboard', 'my_leave', 'hr_dashboard', 'hr_directory', 'hr_recruitment',
    'hr_leave_calendar', 'hr_attendance', 'hr_payroll', 'hr_approvals',
    'hr_reports', 'hr_settings', 'reports', 'settings', 'notifications',
  },
  'procurement_manager' => {'dashboard', 'approvals', 'inventory', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  // No 'staff' (the task-assignment board) — accountant handles payments,
  // not staff task assignment.
  'accountant'     => {'dashboard', 'approvals', 'revenue', 'finance', 'my_leave', 'reports', 'settings', 'notifications'},
  'logistics'      => {'dashboard', 'inventory', 'sales', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
  _                => {'dashboard', 'staff', 'my_leave', 'reports', 'settings', 'notifications'},
};

/// Returns the default landing screen key for [role].
String defaultScreenKey(String role) => switch (role) {
  'cto' || 'team_leader'           => 'approvals',
  'technician'                    => 'service',
  'sales_manager' || 'sales'      => 'sales',
  'cs'                             => 'customers',
  'storekeeper'                    => 'inventory',
  'procurement_manager' || 'accountant' => 'approvals',
  'logistics'                      => 'inventory',
  _                                => 'dashboard',
};

/// Roles with authority to approve/reject quotations and sales orders that
/// exceeded a rep's discount limits — mirrors User::SALES_APPROVAL_ROLES on
/// the backend (which is the actual enforcement; this only toggles the button).
bool hasSalesApprovalAuthority(String role) =>
    const {'super_admin', 'admin', 'sales_manager'}.contains(role);

/// Mirrors User::CTO_TIER on the backend (which is the actual enforcement;
/// this only toggles which action buttons render).
bool hasCtoApprovalAuthority(String role) =>
    const {'super_admin', 'admin', 'cto'}.contains(role);

/// Mirrors User::TEAM_LEAD_APPROVAL_ROLES.
bool hasTeamLeadAuthority(String role) =>
    hasCtoApprovalAuthority(role) || role == 'team_leader';

/// Mirrors User::hasDirectorAuthority() (== ADMIN_TIER).
bool hasDirectorAuthority(String role) =>
    const {'super_admin', 'admin'}.contains(role);

/// Mirrors the procurement.create_po grant (procurement_manager + admin tier).
bool hasProcurementCreateAuthority(String role) =>
    const {'super_admin', 'admin', 'procurement_manager'}.contains(role);

/// Mirrors the procurement.approve_po_sales_stage grant.
bool hasProcurementSalesStageAuthority(String role) =>
    const {'super_admin', 'admin', 'sales_manager'}.contains(role);

/// Mirrors the procurement.initiate_payment grant (accountant + admin tier).
bool hasAccountantAuthority(String role) =>
    const {'super_admin', 'admin', 'accountant'}.contains(role);

/// Mirrors User::hasServiceTicketCreateAuthority() on the backend (screens.service)
/// — the actual enforcement lives there; this only toggles the "New Ticket"
/// shortcut that's reachable from the Dashboard, not just the Service screen
/// itself (which is already hidden from these roles by allowedScreenKeys).
bool hasServiceTicketCreateAuthority(String role) {
  final allowed = allowedScreenKeys(role);
  return allowed == null || allowed.contains('service');
}

/// Mirrors the services.close_ticket grant (backend authority, this only
/// toggles the Resolve button) — resolving a ticket is CTO/Director work,
/// not the assigned technician's.
bool hasServiceTicketResolveAuthority(String role) =>
    const {'super_admin', 'admin', 'cto', 'team_leader'}.contains(role);

/// Mirrors the staff.manage grant (create/edit/deactivate staff, change
/// roles) — hr + admin tier.
bool hasStaffManageAuthority(String role) =>
    const {'super_admin', 'admin', 'hr'}.contains(role);

/// Derive initials from a display name (e.g. "Joseph Mwakasege" → "JM").
String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  if (parts.first.isNotEmpty) return parts.first[0].toUpperCase();
  return '?';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stored     = await AuthService.instance.getStoredToken();
  final storedName = await AuthService.instance.getStoredUserName();
  var   storedRole = await AuthService.instance.getStoredRole();
  final storedId   = await AuthService.instance.getStoredUserId();
  authTokenNotifier = ValueNotifier<String?>(stored);
  userNameNotifier.value = storedName ?? '';
  userIdNotifier.value   = storedId;

  // If already logged in but role or id wasn't cached (e.g. logged in before
  // that storage was introduced), fetch it from /auth/me now before rendering.
  if (stored != null && (storedRole == null || storedRole.isEmpty || storedId == null)) {
    final profile = await AuthService.instance.getProfile();
    storedRole = profile?['role'] as String?;
    final freshName = profile?['name'] as String?;
    if (freshName != null && freshName.isNotEmpty) {
      userNameNotifier.value = freshName;
    }
    final freshId = profile?['id'];
    if (freshId is num) userIdNotifier.value = freshId.toInt();
  }

  userRoleNotifier.value = storedRole ?? '';

  // Permission refresh, trial check, and local-notifier setup are all
  // independent of each other — run them concurrently instead of stacked
  // sequential awaits, so a slow/unreachable network only costs one wait
  // before the first frame renders, not three added together. All three are
  // already internally timeout-bounded and catch their own errors.
  final trialFuture = TrialService.instance.check();
  final otherFutures = <Future<void>>[
    localNotifier.setup(appName: 'Hypermed'),
    if (stored != null) refreshPermissions(),
  ];
  await Future.wait(otherFutures);
  trialNotifier = ValueNotifier<TrialStatus>(await trialFuture);

  runApp(const HypermedApp());
}

class HypermedApp extends StatelessWidget {
  const HypermedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        // theme/darkTheme are set to the same ThemeData for every mode
        // except plain light/dark, so themeMode only actually matters for
        // that pair — the other modes are single fixed palettes.
        final resolvedTheme = AppTheme.of(mode);
        return MaterialApp(
        title: 'Hypermed',
        debugShowCheckedModeBanner: false,
        theme:     resolvedTheme,
        darkTheme: resolvedTheme,
        themeMode: mode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
        // App-wide text bump — multiplies on top of the device's own text
        // scale rather than replacing it, so OS accessibility settings still
        // apply. User-adjustable via Settings → Preferences → Text Size.
        builder: (context, child) => ValueListenableBuilder<TextSizePref>(
          valueListenable: textSizeNotifier,
          builder: (_, sizePref, _) {
            final mq = MediaQuery.of(context);
            final deviceFactor = mq.textScaler.scale(1.0);
            return MediaQuery(
              data: mq.copyWith(
                  textScaler: TextScaler.linear(deviceFactor * sizePref.scale)),
              child: child!,
            );
          },
        ),
        home: ValueListenableBuilder<TrialStatus>(
          valueListenable: trialNotifier,
          builder: (_, trial, _) {
            // Awaiting admin approval
            if (trial.isPending) {
              return TrialPendingScreen(status: trial);
            }
            // Trial expired / revoked → show locked screen regardless of auth
            if (!trial.isValid) {
              return TrialExpiredScreen(status: trial);
            }
            // Normal auth gate
            return ValueListenableBuilder<String?>(
              valueListenable: authTokenNotifier,
              builder: (_, token, _) =>
                  token == null ? const LoginScreen() : const AppShell(),
            );
          },
        ),
      );
      },
    );
  }
}
