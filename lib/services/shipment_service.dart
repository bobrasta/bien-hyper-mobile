import 'package:dio/dio.dart';
import '../models/shipment.dart';
import 'api_client.dart';

/// Section 18 — ShipmentController.
class ShipmentService {
  ShipmentService._();
  static final instance = ShipmentService._();
  final _dio = ApiClient.instance.dio;

  Map<String, dynamic> _map(Response res) => Map<String, dynamic>.from(ApiClient.unwrap(res) as Map);

  // Stale-while-revalidate cache for the list (see MachineService).
  static ShipmentList? cachedList;

  Future<ShipmentList> list() async {
    final m = _map(await _dio.get('/shipments'));
    final list = ShipmentList(
      shipments: [for (final s in (m['shipments'] as List? ?? [])) Shipment(Map<String, dynamic>.from(s as Map))],
      counts: {for (final e in (m['counts'] as Map? ?? {}).entries) e.key as String: (e.value as num).toInt()},
      canManage: m['can_manage'] == true,
    );
    cachedList = list;
    return list;
  }

  Future<Shipment> get(int id) async => Shipment(_map(await _dio.get('/shipments/$id')));

  /// [files] maps a document type (bill_of_lading, coa…) to a local path.
  Future<Shipment> create(Map<String, dynamic> data, Map<String, ({String path, String name})> files) async {
    final form = FormData.fromMap({
      for (final e in data.entries) if (e.value != null) e.key: e.value,
      for (final f in files.entries) 'documents[${f.key}]': await MultipartFile.fromFile(f.value.path, filename: f.value.name),
    });
    return Shipment(_map(await _dio.post('/shipments', data: form)));
  }

  Future<Shipment> update(int id, Map<String, dynamic> data) async => Shipment(_map(await _dio.put('/shipments/$id', data: data)));

  Future<Shipment> setStep(int id, Map<String, dynamic> data) async =>
      Shipment(_map(await _dio.post('/shipments/$id/status', data: data)));

  Future<Shipment> uploadDocument(int id, String type, String path, String name) async {
    final form = FormData.fromMap({'type': type, 'file': await MultipartFile.fromFile(path, filename: name)});
    return Shipment(_map(await _dio.post('/shipments/$id/documents', data: form)));
  }

  Future<List<int>> downloadDocument(int id, String type) async {
    final res = await _dio.get<List<int>>('/shipments/$id/documents/$type', options: Options(responseType: ResponseType.bytes));
    return res.data!;
  }

  Future<Shipment> linkClearingFee(int id, Map<String, dynamic> data) async =>
      Shipment(_map(await _dio.post('/shipments/$id/clearing-fee', data: data)));

  Future<Shipment> syncMachines(int id, List<int> machineIds) async =>
      Shipment(_map(await _dio.put('/shipments/$id/machines', data: {'machine_ids': machineIds})));

  Future<ShipmentOptions> options() async => ShipmentOptions(_map(await _dio.get('/shipments/options')));

  Future<ShipmentSettings> settings() async => ShipmentSettings(_map(await _dio.get('/shipments/settings')));

  Future<ShipmentSettings> saveSettings(Map<String, dynamic> data) async =>
      ShipmentSettings(_map(await _dio.put('/shipments/settings', data: data)));

  Future<void> saveDepartment(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _dio.post('/departments', data: data);
    } else {
      await _dio.put('/departments/$id', data: data);
    }
  }
}
