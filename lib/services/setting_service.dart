import 'api_client.dart';

class SettingService {
  SettingService._();
  static final instance = SettingService._();
  final _dio = ApiClient.instance.dio;

  Future<Map<String, String?>> all() async {
    final res = await _dio.get('/settings');
    final data = ApiClient.unwrap(res) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v as String?));
  }

  Future<void> set(String key, String value) => _dio.put('/settings/$key', data: {'value': value});
}
