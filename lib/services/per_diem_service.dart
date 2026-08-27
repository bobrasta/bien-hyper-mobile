import '../models/per_diem_request.dart';
import 'api_client.dart';

class PerDiemService {
  PerDiemService._();
  static final instance = PerDiemService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PerDiemRequest>> list({String? status}) async {
    final res = await _dio.get('/per-diem-requests', queryParameters: {
      'status': ?status,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PerDiemRequest.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PerDiemRequest> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/per-diem-requests', data: data);
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> approveTeamLead(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/approve-team-lead');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> rejectTeamLead(int id, {String? reason}) async {
    final res = await _dio.post('/per-diem-requests/$id/reject-team-lead', data: {'rejection_reason': reason});
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> approve(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/approve');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> reject(int id, {String? reason}) async {
    final res = await _dio.post('/per-diem-requests/$id/reject', data: {'rejection_reason': reason});
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> cancel(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/cancel');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> markPaid(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/mark-paid');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
