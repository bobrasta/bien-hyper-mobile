import '../models/position_change.dart';
import 'api_client.dart';

export '../models/position_change.dart';

class PositionChangeService {
  PositionChangeService._();
  static final instance = PositionChangeService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PositionChange>> list(int userId) async {
    final res = await _dio.get('/staff/$userId/position-changes');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PositionChange.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PositionChange> create(int userId, Map<String, dynamic> data) async {
    final res = await _dio.post('/staff/$userId/position-changes', data: data);
    return PositionChange.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
