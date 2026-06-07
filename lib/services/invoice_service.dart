import '../models/invoice.dart';
import 'api_client.dart';

class InvoiceService {
  InvoiceService._();
  static final instance = InvoiceService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Invoice>> list({String? status, String? search, int? salesOrderId, int? machineId}) async {
    final res = await _dio.get('/invoices', queryParameters: {
      'status':          ?status,
      'search':          ?search,
      'sales_order_id':  ?salesOrderId,
      'machine_id':      ?machineId,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Invoice.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Invoice> get(int id) async {
    final res = await _dio.get('/invoices/$id');
    return Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Invoice> send(int id) async {
    final res = await _dio.post('/invoices/$id/send');
    return Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Invoice> cancel(int id) async {
    final res = await _dio.post('/invoices/$id/cancel');
    return Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> recordPayment(int id, Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices/$id/payments', data: data);
    final body = res.data as Map<String, dynamic>;
    return {
      'payment': Payment.fromJson(body['data'] as Map<String, dynamic>),
      'invoice': Invoice.fromJson(body['invoice'] as Map<String, dynamic>),
    };
  }

  Future<Invoice> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices', data: data);
    return Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Invoice> fromSalesOrder(int salesOrderId) async {
    final res = await _dio.post('/sales-orders/$salesOrderId/invoice');
    return Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> revenueSummary() async {
    try {
      final res = await _dio.get('/revenue/summary');
      final raw = ApiClient.unwrap(res);
      if (raw is Map<String, dynamic>) return raw;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> revenueByHospital() async {
    try {
      final res = await _dio.get('/revenue/by-hospital');
      final (data, _) = ApiClient.unwrapList(res);
      return data.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}
