import '../models/public_holiday.dart';
import 'api_client.dart';

export '../models/public_holiday.dart';

class PublicHolidayService {
  PublicHolidayService._();
  static final instance = PublicHolidayService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PublicHoliday>> list({int? year}) async {
    final res = await _dio.get('/public-holidays', queryParameters: {'year': ?year});
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PublicHoliday.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PublicHoliday> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/public-holidays', data: data);
    return PublicHoliday.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/public-holidays/$id');
}
