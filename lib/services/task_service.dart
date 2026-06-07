import '../models/task_item.dart';
import 'api_client.dart';

class TaskService {
  TaskService._();
  static final instance = TaskService._();

  final _dio = ApiClient.instance.dio;

  Future<List<TaskItem>> list({int? assignedTo, String? status, String? category}) async {
    final res = await _dio.get('/tasks', queryParameters: {
      'assigned_to': ?assignedTo,
      'status':      ?status,
      'category':    ?category,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskItem> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/tasks', data: data);
    return TaskItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<TaskItem> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/tasks/$id', data: data);
    return TaskItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/tasks/$id');
  }
}
