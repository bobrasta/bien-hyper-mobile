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

  // rejection_reason is required server-side (min 10 chars) — no self-
  // approval and no un-reasoned rejection are both enforced in
  // PerDiemController now, so this is never optional in practice despite
  // the nullable type (callers must prompt before calling).
  Future<PerDiemRequest> rejectTeamLead(int id, {required String reason}) async {
    final res = await _dio.post('/per-diem-requests/$id/reject-team-lead', data: {'rejection_reason': reason});
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> approve(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/approve');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> reject(int id, {required String reason}) async {
    final res = await _dio.post('/per-diem-requests/$id/reject', data: {'rejection_reason': reason});
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemRequest> cancel(int id, {required String reason}) async {
    final res = await _dio.post('/per-diem-requests/$id/cancel', data: {'cancellation_reason': reason});
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  /// Finance's step — prepares the payment but doesn't move money on their
  /// own authority. Director's markPaid() below is the actual release.
  Future<PerDiemRequest> initiatePayment(int id, {String? method, String? reference}) async {
    final res = await _dio.post('/per-diem-requests/$id/initiate-payment', data: {
      'payment_method':    ?method,
      'payment_reference': ?reference,
    });
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  /// Director's final authorization — only reachable once finance has
  /// initiated payment.
  Future<PerDiemRequest> markPaid(int id) async {
    final res = await _dio.post('/per-diem-requests/$id/mark-paid');
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  // Section 8: CTO day-by-day editing — sends the full day list every time
  // (no from_seq_no), which correctly covers all three spec modes (single
  // day, add/remove days) since the server always recomputes from what's
  // submitted; only loses the "provably untouched earlier days" optimization,
  // not correctness.
  Future<PerDiemRequest> revise(int id, {required String reason, required List<PerDiemLine> lines}) async {
    final res = await _dio.post('/per-diem-requests/$id/revise', data: {
      'reason': reason,
      'lines': lines.map((l) => l.toJson()).toList(),
    });
    return PerDiemRequest.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PerDiemEditGrant> grantEditAccess(int id, {String? expiresAt}) async {
    final res = await _dio.post('/per-diem-requests/$id/edit-grants', data: {
      'expires_at': ?expiresAt,
    });
    return PerDiemEditGrant.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> revokeEditAccess(int id) => _dio.delete('/per-diem-requests/$id/edit-grants');
}
