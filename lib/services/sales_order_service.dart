import '../models/sales_order.dart';
import 'api_client.dart';

class SalesOrderService {
  SalesOrderService._();
  static final instance = SalesOrderService._();
  final _dio = ApiClient.instance.dio;

  Future<List<SalesOrder>> list({String? status, String? search}) async {
    final res = await _dio.get('/sales-orders', queryParameters: {
      'status': ?status,
      'search': ?search,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => SalesOrder.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<SalesOrder> get(int id) async {
    final res = await _dio.get('/sales-orders/$id');
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SalesOrder> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/sales-orders', data: data);
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SalesOrder> confirm(int id) async {
    final res = await _dio.post('/sales-orders/$id/confirm');
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  /// Returns the updated order plus how many Machine records this delivery
  /// registered (equipment items delivered to a hospital-linked order).
  Future<(SalesOrder, int machinesCreated)> deliver(int id, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final res = await _dio.post('/sales-orders/$id/deliver', data: {
      'items': items,
      'notes': ?notes,
    });
    final body = res.data as Map<String, dynamic>;
    final order = SalesOrder.fromJson(body['data'] as Map<String, dynamic>);
    final machinesCreated = (body['machines_created'] as List?)?.length ?? 0;
    return (order, machinesCreated);
  }

  Future<SalesOrder> cancel(int id) async {
    final res = await _dio.post('/sales-orders/$id/cancel');
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SalesOrder> approve(int id) async {
    final res = await _dio.post('/sales-orders/$id/approve');
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SalesOrder> rejectApproval(int id, {String? reason}) async {
    final res = await _dio.post('/sales-orders/$id/reject-approval', data: {
      'rejection_reason': ?reason,
    });
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
