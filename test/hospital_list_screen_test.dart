import 'package:bienhypermed/models/hospital.dart';
import 'package:bienhypermed/screens/machines/machine_map_screen.dart';
import 'package:bienhypermed/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:bienhypermed/screens/hospitals/hospital_list_screen.dart';
import 'package:bienhypermed/services/hospital_service.dart';
import 'package:bienhypermed/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

Hospital _h(int id, {double lat = -8.9, double lng = 33.45}) => Hospital.fromJson(_json(id, lat: lat, lng: lng));

Map<String, dynamic> _json(int id, {double lat = -8.9, double lng = 33.45}) => {
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
    };

/// Answers every API call with one hospital and records /hospitals queries.
List<Map<String, dynamic>> stubApi() {
  final queries = <Map<String, dynamic>>[];
  final spy = InterceptorsWrapper(onRequest: (o, h) {
    if (o.path == '/hospitals') queries.add(Map.of(o.queryParameters));
    h.resolve(Response(requestOptions: o, statusCode: 200, data: {
      'data': [_json(1)],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
    }));
  });
  ApiClient.instance.dio.interceptors.insert(0, spy);
  addTearDown(() => ApiClient.instance.dio.interceptors.remove(spy));
  return queries;
}

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

  // Filters go to the API (the directory is server-paged), and the old
  // placeholder pills/Columns button are gone.
  testWidgets('region, zone and machines filters query the API', (tester) async {
    final queries = stubApi();
    await pump(tester, const Size(1400, 900));
    expect(find.text('Columns'), findsNothing);
    expect(find.text('All regions'), findsOneWidget);

    Future<void> pick(String filter, String item) async {
      await tester.tap(find.byKey(Key(filter)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    await pick('regionFilter', 'Dar Es Salaam');
    expect(queries.last['region'], 'Dar Es Salaam');
    await pick('zoneFilter', 'Lake Zone');
    expect(queries.last['zone'], 'lake');
    await pick('machinesFilter', 'With machines');
    expect(queries.last['has_machines'], 1);
    expect(queries.last['region'], 'Dar Es Salaam');
    expect(queries.last['page'], 1);
  }, variant: desktop);

  testWidgets('Map View opens the fleet map and List view returns', (tester) async {
    stubApi();
    await pump(tester, const Size(1400, 900));
    await tester.tap(find.text('Map View'));
    await tester.pump();
    expect(find.byType(MachineMapScreen), findsOneWidget);
    await tester.tap(find.text('List view'));
    await tester.pump();
    expect(find.byType(MachineMapScreen), findsNothing);
    expect(find.text('HOSPITAL'), findsOneWidget);
    // Let the map's tile loads time out.
    await tester.pump(const Duration(minutes: 1));
  }, variant: desktop);
}
