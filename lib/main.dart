import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'screens/auth/login_screen.dart';
import 'screens/trial/trial_expired_screen.dart' show TrialExpiredScreen, TrialPendingScreen;
import 'services/auth_service.dart';
import 'services/trial_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_shell.dart';

/// Global theme-mode notifier — toggled by the top-bar button or Settings.
final themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.dark);

/// Global auth token — null means not logged in, non-null means authenticated.
late final ValueNotifier<String?> authTokenNotifier;

/// Global logged-in user's display name — updated on login and profile save.
final userNameNotifier = ValueNotifier<String>('');

/// Global trial status — checked once on startup.
late final ValueNotifier<TrialStatus> trialNotifier;

/// Global logged-in user's role — drives sidebar filtering and screen guards.
final userRoleNotifier = ValueNotifier<String>('');

/// Unread notification count — updated by BackgroundSync; drives the bell badge.
final notificationCountNotifier = ValueNotifier<int>(0);

/// Returns the set of screen keys accessible for [role].
/// Returns null for admin/manager (full access).
Set<String>? allowedScreenKeys(String role) => switch (role) {
  'admin'   || 'manager' => null,
  'technician' => {'dashboard', 'machines', 'detail', 'hospitals', 'service', 'inventory', 'staff', 'reports', 'settings'},
  'sales'      => {'dashboard', 'machines', 'detail', 'sales', 'customers', 'revenue', 'email', 'staff', 'reports', 'settings'},
  'finance'    => {'dashboard', 'revenue', 'staff', 'reports', 'settings'},
  'cs'         => {'dashboard', 'customers', 'service', 'email', 'staff', 'reports', 'settings'},
  _            => {'dashboard', 'staff', 'reports', 'settings'},
};

/// Returns the default landing screen key for [role].
String defaultScreenKey(String role) => switch (role) {
  'technician' => 'service',
  'sales'      => 'sales',
  'finance'    => 'revenue',
  'cs'         => 'customers',
  _            => 'dashboard',
};

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
  authTokenNotifier = ValueNotifier<String?>(stored);
  userNameNotifier.value = storedName ?? '';

  // If already logged in but role wasn't cached (e.g. logged in before role
  // storage was introduced), fetch it from /auth/me now before rendering.
  if (stored != null && (storedRole == null || storedRole.isEmpty)) {
    final profile = await AuthService.instance.getProfile();
    storedRole = profile?['role'] as String?;
    final freshName = profile?['name'] as String?;
    if (freshName != null && freshName.isNotEmpty) {
      userNameNotifier.value = freshName;
    }
  }

  userRoleNotifier.value = storedRole ?? '';

  await localNotifier.setup(appName: 'Hypermed');

  // Trial check — runs before the app renders
  final trialStatus = await TrialService.instance.check();
  trialNotifier = ValueNotifier<TrialStatus>(trialStatus);

  runApp(const HypermedApp());
}

class HypermedApp extends StatelessWidget {
  const HypermedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) { 
        final isNeutral = mode == AppThemeMode.neutral;
        return MaterialApp(
        title: 'Hypermed',
        debugShowCheckedModeBanner: false,
        theme:     isNeutral ? AppTheme.neutral() : AppTheme.light(),
        darkTheme: isNeutral ? AppTheme.neutral() : AppTheme.dark(),
        themeMode: mode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
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
