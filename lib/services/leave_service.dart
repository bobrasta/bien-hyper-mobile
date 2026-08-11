import '../models/leave_request.dart';
import 'api_client.dart';

class LeaveService {
  LeaveService._();
  static final instance = LeaveService._();
  final _dio = ApiClient.instance.dio;

  Future<List<LeaveRequest>> list({int? userId, String? status, String? type}) async {
    final res = await _dio.get('/leave-requests', queryParameters: {
      'user_id': ?userId,
      'status':  ?status,
      'type':    ?type,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => LeaveRequest.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<LeaveRequest> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/leave-requests', data: data);
    return LeaveRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<LeaveRequest> approve(int id) async {
    final res = await _dio.post('/leave-requests/$id/approve');
    return LeaveRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<LeaveRequest> reject(int id, {String? reason}) async {
    final res = await _dio.post('/leave-requests/$id/reject', data: {'rejection_reason': reason});
    return LeaveRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<LeaveRequest> cancel(int id) async {
    final res = await _dio.post('/leave-requests/$id/cancel');
    return LeaveRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
