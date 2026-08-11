import '../models/late_arrival.dart';
import 'api_client.dart';

class LateArrivalService {
  LateArrivalService._();
  static final instance = LateArrivalService._();
  final _dio = ApiClient.instance.dio;

  Future<List<LateArrival>> list({int? userId, String? dateFrom, String? dateTo}) async {
    final res = await _dio.get('/late-arrivals', queryParameters: {
      'user_id':   ?userId,
      'date_from': ?dateFrom,
      'date_to':   ?dateTo,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => LateArrival.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<LateArrival> report({String? expectedTime, String? reason}) async {
    final res = await _dio.post('/late-arrivals', data: {
      'expected_time': expectedTime,
      'reason': reason,
    });
    return LateArrival.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
