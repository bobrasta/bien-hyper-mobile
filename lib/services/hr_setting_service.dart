import 'api_client.dart';

class HrSettingService {
  HrSettingService._();
  static final instance = HrSettingService._();
  final _dio = ApiClient.instance.dio;

  Future<Map<String, String>> get() async {
    final res = await _dio.get('/hr-settings');
    final raw = ApiClient.unwrap(res) as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  Future<Map<String, String>> update(Map<String, String> settings) async {
    final res = await _dio.put('/hr-settings', data: {'settings': settings});
    final raw = ApiClient.unwrap(res) as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}
