import 'package:bienhypermed/main.dart';
import 'package:bienhypermed/services/api_client.dart';
import 'package:bienhypermed/services/trial_service.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:bienhypermed/widgets/common/app_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _tickets = [
  for (final (i, machine) in [(1, 'Siemens Somatom CT'), (2, 'GE Logiq E10')])
    {
      'id': i, 'ticket_number': 'TK-$i', 'machine_name': machine, 'hospital': 'KCMC',
      'status': 'open', 'technician_name': 'Asha Mollel', 'created_at': '2026-09-2$i',
    },
];

/// Answers /tickets with [_tickets] and every other API call with an empty
/// list, so screens render without reaching the network.
void _stubApi() {
  ApiClient.instance.dio.interceptors.insert(0, InterceptorsWrapper(onRequest: (o, h) {
    final data = o.path == '/tickets' ? _tickets : <dynamic>[];
    h.resolve(Response(requestOptions: o, statusCode: 200, data: {
      'data': data,
      'meta': {'current_page': 1, 'last_page': 1, 'total': data.length},
    }));
  }));
}

Future<void> _pumpPhone(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  userRoleNotifier.value = role;
  userPermissionsNotifier.value = {};
  await tester.pumpWidget(MaterialApp(theme: AppTheme.of(AppThemeMode.dark), home: const AppShell()));
  await tester.pump(const Duration(seconds: 1));
}

/// Unmounts the shell (stops its background sync) before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The bottom bar's labels, left to right.
List<String> _tabLabels(WidgetTester tester) {
  final bar = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BottomTabBar');
  return tester
      .widgetList<Text>(find.descendant(of: bar, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .toList();
}

void main() {
  setUpAll(() {
    try {
      trialNotifier = ValueNotifier(const TrialStatus(state: TrialState.valid));
    } catch (_) {/* already set by another test in this isolate */}
    _stubApi();
  });

  testWidgets('phone tabs follow the role — HR never sees Machines/Service/Revenue', (tester) async {
    await _pumpPhone(tester, 'hr');
    expect(_tabLabels(tester), ['Home', 'Directory', 'HR Approvals', 'Attendance', 'More']);
    await _unmount(tester);
  });

  testWidgets('technician lands on Service and gets Machines as a tab', (tester) async {
    await _pumpPhone(tester, 'technician');
    expect(_tabLabels(tester), ['Home', 'Service', 'Machines', 'My Leave', 'More']);
    await _unmount(tester);
  });

  testWidgets('top bar shows the page title; back goes to Home before leaving', (tester) async {
    await _pumpPhone(tester, 'storekeeper');
    expect(_tabLabels(tester), ['Home', 'Items', 'Machines', 'Staff', 'More']);
    // Storekeeper lands on Inventory → title names it.
    expect(find.text('Items'), findsNWidgets(2)); // top bar + tab
    expect(find.text('Inventory Items'), findsOneWidget); // the screen's own header

    final exits = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'SystemNavigator.pop') exits.add(c);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Home'), findsNWidgets(2), reason: 'back from a tab returns to Home');
    expect(exits, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, hasLength(1), reason: 'back on Home leaves the app');
    await _unmount(tester);
  });

  testWidgets('search icon opens full-screen search on phones', (tester) async {
    await _pumpPhone(tester, 'technician');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('Search machines, hospitals, tickets…'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Search machines, hospitals, tickets…'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Service on a phone opens on the list; back closes an open ticket', (tester) async {
    await _pumpPhone(tester, 'technician');
    expect(find.text('Siemens Somatom CT'), findsOneWidget);
    expect(find.text('Back to list'), findsNothing, reason: 'no ticket opened by itself');

    await tester.tap(find.text('Siemens Somatom CT'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Back to list'), findsOneWidget);
    expect(find.text('Service Tickets'), findsNothing, reason: 'list header hides behind an open ticket');

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Back to list'), findsNothing);
    expect(find.text('Service Tickets'), findsOneWidget);
    expect(find.text('Service'), findsWidgets, reason: 'still on Service, not sent Home');
    await _unmount(tester);
  });
}
