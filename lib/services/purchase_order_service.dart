import '../models/purchase_order.dart';
import 'api_client.dart';

class PurchaseOrderService {
  PurchaseOrderService._();
  static final instance = PurchaseOrderService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PurchaseOrder>> list({String? status, int? supplierId}) async {
    final res = await _dio.get('/purchase-orders', queryParameters: {
      'status':      ?status,
      'supplier_id': ?supplierId,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PurchaseOrder.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PurchaseOrder> get(int id) async {
    final res = await _dio.get('/purchase-orders/$id');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/purchase-orders', data: data);
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> send(int id) async {
    final res = await _dio.post('/purchase-orders/$id/send');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> receive(int id, Map<String, dynamic> data) async {
    final res = await _dio.post('/purchase-orders/$id/receive', data: data);
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> cancel(int id) async {
    final res = await _dio.post('/purchase-orders/$id/cancel');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  // ── Approval / payment chain ──────────────────────────────────────────────
  // draft -> pending_sales_manager -> pending_director_review ->
  // pending_payment_initiation -> pending_director_final -> approved.

  Future<PurchaseOrder> submitForApproval(int id) async {
    final res = await _dio.post('/purchase-orders/$id/submit-for-approval');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> approveSalesManager(int id) async {
    final res = await _dio.post('/purchase-orders/$id/approve-sales-manager');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> rejectSalesManager(int id, {String? reason}) async {
    final res = await _dio.post('/purchase-orders/$id/reject-sales-manager',
        data: {'rejection_reason': reason});
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> approveDirectorReview(int id) async {
    final res = await _dio.post('/purchase-orders/$id/approve-director-review');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> rejectDirectorReview(int id, {String? reason}) async {
    final res = await _dio.post('/purchase-orders/$id/reject-director-review',
        data: {'rejection_reason': reason});
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> initiatePayment(int id, {int? amountPaid}) async {
    final res = await _dio.post('/purchase-orders/$id/initiate-payment',
        data: {'amount_paid': ?amountPaid});
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> approveDirectorFinal(int id) async {
    final res = await _dio.post('/purchase-orders/$id/approve-director-final');
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseOrder> rejectDirectorFinal(int id, {String? reason}) async {
    final res = await _dio.post('/purchase-orders/$id/reject-director-final',
        data: {'rejection_reason': reason});
    return PurchaseOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
