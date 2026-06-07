import '../models/machine.dart';
import 'api_client.dart';

class MachineService {
  MachineService._();
  static final instance = MachineService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Machine>> list({String? status, int? hospitalId, String? type}) async {
    final res = await _dio.get('/machines', queryParameters: {
      'status':      ?status,
      'hospital_id': ?hospitalId,
      'type':        ?type,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Machine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Machine> get(int id) async {
    final res = await _dio.get('/machines/$id');
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<List<Machine>> mapPins() async {
    final res = await _dio.get('/machines/map');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Machine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Machine> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/machines', data: data);
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Machine> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/machines/$id', data: data);
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/machines/$id');
}
