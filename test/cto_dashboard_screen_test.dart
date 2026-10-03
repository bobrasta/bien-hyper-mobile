import 'package:bienhypermed/screens/dashboard/cto_dashboard_screen.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Lays the CTO dashboard out with sample data at the desktop (2a) and
// mobile (2b) breakpoints — catches RenderFlex overflows in either layout.
void main() {
  for (final (label, size) in [('desktop', const Size(1440, 1400)), ('mobile', const Size(390, 2200))]) {
    testWidgets('lays out without overflow on $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CtoDashboardScreen(useSampleData: true)),
      ));
      await tester.pump();

      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text(label == 'desktop' ? 'Awaiting your approval' : 'Awaiting you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
