import 'package:bienhypermed/models/hospital.dart';
import 'package:bienhypermed/screens/hospitals/hospital_list_screen.dart';
import 'package:bienhypermed/services/hospital_service.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

Hospital _h(int id, {double lat = -8.9, double lng = 33.45}) => Hospital.fromJson({
      'id': id,
      'name': 'Facility $id Hospital',
      'short_code': 'F$id',
      'type': 'private',
      'region': 'Mbeya',
      'district': 'Mbeya CC',
      'zone': 'shighland',
      'latitude': lat,
      'longitude': lng,
      'machine_count': 3,
      'machines_operational': 2,
      'contact_name': 'Dr. Contact $id',
      'contact_phone': '0754 000 00$id',
    });

void main() {
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    HospitalService.cachedFirstPage = HospitalPage(items: [_h(1), _h(2, lat: 0, lng: 0)], currentPage: 1, lastPage: 1, total: 2);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: HospitalListScreen())));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('four columns with sub lines, no uptime, no sideways scroll', (tester) async {
    await pump(tester, const Size(1400, 900));
    for (final h in ['HOSPITAL', 'LOCATION', 'MACHINES', 'CONTACT']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    for (final h in ['UPTIME', 'REGION', 'TYPE']) {
      expect(find.text(h), findsNothing, reason: h);
    }
    expect(find.text('Mbeya CC'), findsNWidgets(2));
    expect(find.text('Mbeya · Southern Highlands zone'), findsNWidgets(2));
    expect(find.text('Private  ·  F1', findRichText: true), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal), findsNothing);
  }, variant: desktop);

  testWidgets('narrow window drops Contact and Machines', (tester) async {
    await pump(tester, const Size(620, 900));
    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('CONTACT'), findsNothing);
    expect(find.text('MACHINES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  testWidgets('pin opens the map; no pin action without coordinates', (tester) async {
    await pump(tester, const Size(1400, 900));
    expect(find.byTooltip('See on map'), findsOneWidget);
    expect(find.byTooltip('No location saved'), findsOneWidget);
    await tester.tap(find.byTooltip('See on map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('-8.90000, 33.45000'), findsOneWidget);
    expect(find.text('Mbeya CC · Mbeya · Southern Highlands zone'), findsOneWidget);
  }, variant: desktop);
}
