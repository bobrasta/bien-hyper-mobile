import '../models/hospital.dart';
import 'api_client.dart';

class HospitalService {
  HospitalService._();
  static final instance = HospitalService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Hospital>> list({String? type, String? region}) async {
    final res = await _dio.get('/hospitals',
      queryParameters: {
        'type': ?type,
        'region': ?region,
      },
      options: ApiClient.cachingOptions(const Duration(minutes: 30)),
    );
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Hospital.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Hospital> get(int id) async {
    final res = await _dio.get('/hospitals/$id');
    return Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Hospital> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/hospitals', data: data);
    return Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Hospital> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/hospitals/$id', data: data);
    return Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/hospitals/$id');
}
