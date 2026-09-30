import 'package:bienhypermed/models/invoice.dart';
import 'package:bienhypermed/screens/sales/invoice_builder_screen.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: screen));
    await tester.pump(const Duration(milliseconds: 50));
  }

  final draft = Invoice.fromJson({
    'id': 9, 'invoice_number': 'DRAFT-2026-0003', 'client_name': 'Mwangaza Polyclinic',
    'issue_date': '2026-09-30', 'due_date': '2026-10-30', 'pay_term_number': 30, 'pay_term_type': 'days',
    'subtotal': 50000, 'total': 50000, 'amount_paid': 0, 'status': 'draft', 'sale_status': 'draft',
    'staff_note': 'confirm price', 'line_items': [{'description': 'X-ray film', 'quantity': 10, 'unit_price': 5000, 'total': 50000}],
  });

  testWidgets('new sale offers Final / Draft / Quotation / Proforma', (tester) async {
    await pump(tester, const InvoiceBuilderScreen());
    expect(find.text('Add sale'), findsOneWidget);
    expect(find.text('Status *'), findsOneWidget);
    await tester.tap(find.text('Final').first);
    await tester.pumpAndSettle();
    for (final s in ['Draft', 'Quotation', 'Proforma']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await tester.tap(find.text('Draft').last);
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Client TIN'), findsOneWidget); // optional for a draft
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a draft pre-fills it and can finalise', (tester) async {
    await pump(tester, InvoiceBuilderScreen(editing: draft));
    expect(find.text('Edit DRAFT-2026-0003'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'X-ray film'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'confirm price'), findsOneWidget);
    expect(find.text('Quotation'), findsNothing); // not offered when editing
    expect(tester.takeException(), isNull);
  });
}
