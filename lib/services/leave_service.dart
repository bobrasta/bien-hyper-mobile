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

  /// [daysCountOverride] is required by the backend when the leave type's
  /// `requires_manual_days` is true (Compassionate) — the approver sets
  /// the final day count rather than trusting the requester's date range.
  Future<LeaveRequest> approve(int id, {int? daysCountOverride}) async {
    final res = await _dio.post('/leave-requests/$id/approve', data: {
      'days_count': ?daysCountOverride,
    });
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

  Future<List<LeaveTypeCatalogEntry>> types({bool activeOnly = false}) async {
    final res = await _dio.get('/leave-types', queryParameters: {
      if (activeOnly) 'active_only': 'true',
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => LeaveTypeCatalogEntry.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<LeaveTypeCatalogEntry> updateType(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/leave-types/$id', data: data);
    return LeaveTypeCatalogEntry.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<List<LeaveBalanceEntry>> balances({int? userId, int? year}) async {
    final res = await _dio.get('/leave-balances', queryParameters: {
      'user_id': ?userId,
      'year':    ?year,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => LeaveBalanceEntry.fromJson(j as Map<String, dynamic>)).toList();
  }
}
