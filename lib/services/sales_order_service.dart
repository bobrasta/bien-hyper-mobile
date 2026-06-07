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

  Future<SalesOrder> deliver(int id, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final res = await _dio.post('/sales-orders/$id/deliver', data: {
      'items': items,
      'notes': ?notes,
    });
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SalesOrder> cancel(int id) async {
    final res = await _dio.post('/sales-orders/$id/cancel');
    return SalesOrder.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
