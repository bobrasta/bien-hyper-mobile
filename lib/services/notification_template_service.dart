import '../models/notification_template.dart';
import 'api_client.dart';

class NotificationTemplateService {
  NotificationTemplateService._();
  static final instance = NotificationTemplateService._();
  final _dio = ApiClient.instance.dio;

  Future<List<NotificationTemplate>> list() async {
    final res = await _dio.get('/notification-templates');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => NotificationTemplate.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<NotificationTemplate> update(int id, {required String title, required String body}) async {
    final res = await _dio.put('/notification-templates/$id', data: {
      'title_template': title,
      'body_template':  body,
    });
    return NotificationTemplate.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
