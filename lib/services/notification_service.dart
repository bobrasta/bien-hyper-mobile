import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _dio = ApiClient.instance.dio;

  Future<List<AppNotification>> list({bool noCache = false}) async {
    final res = await _dio.get('/notifications',
        options: noCache ? ApiClient.noCache : null);
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(int id)  => _dio.patch('/notifications/$id/read');
  Future<void> markAllRead()     => _dio.post('/notifications/read-all');
}
