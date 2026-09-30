import 'package:bienhypermed/models/invoice.dart';
import 'package:bienhypermed/screens/sales/all_sales_screen.dart';
import 'package:bienhypermed/services/invoice_service.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _sale(int id, {String status = 'pending', String ch = 'due', int total = 1000000, int paid = 0}) => Invoice.fromJson({
      'id': id,
      'invoice_number': 'HH-$id',
      'client_name': 'Client $id Hospital',
      'contact_phone': '0754 000 00$id',
      'issue_date': '2026-09-${10 + id}',
      'due_date': '2026-10-${10 + id}',
      'subtotal': total,
      'total': total,
      'amount_paid': paid,
      'balance_due': total - paid,
      'status': status,
      'payment_status': ch,
      'sale_status': 'final',
      'added_by': id.isEven ? 'Leticia Mvukiye' : 'Moses Kiduduye',
      'total_items': 3,
      'payment_methods': paid > 0 ? ['bank_transfer'] : [],
      'notes': 'Sell note $id',
      'staff_note': id == 1 ? 'check stock' : null,
      'shipping_status': id == 2 ? 'shipped' : null,
    });

void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    InvoiceService.cachedDefaultList = [
      _sale(1),
      _sale(2, status: 'paid', ch: 'paid', paid: 1000000),
      _sale(3, status: 'partial', ch: 'partial', paid: 400000),
    ];
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: AllSalesScreen())));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders Clickhuduma columns, footer totals and the right-click menu', (tester) async {
    await pump(tester, const Size(1600, 1000));

    for (final h in ['Invoice No.', 'Customer name', 'Payment Status', 'Sell Due', 'Added By', 'Staff note']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.text('HH-1'), findsOneWidget);
    expect(find.text('Total (3):'), findsOneWidget);
    expect(find.text('TSh 3,000,000'), findsOneWidget); // total amount
    expect(find.text('TSh 1,600,000'), findsWidgets);   // sell due

    await tester.tap(find.text('HH-3'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    for (final a in ['View', 'Edit', 'Delete', 'Edit Shipping', 'Print Invoice', 'Delivery Note',
                     'Add payment', 'View Payments', 'Duplicate Sell', 'Sell Return', 'Invoice URL', 'New Sale Notification']) {
      expect(find.text(a), findsOneWidget, reason: a);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow window scrolls sideways without overflow', (tester) async {
    await pump(tester, const Size(1000, 800));
    expect(find.text('HH-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
