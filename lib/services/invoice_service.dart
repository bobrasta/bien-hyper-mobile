import 'package:dio/dio.dart';
import '../models/invoice.dart';
import 'api_client.dart';

class InvoiceService {
  InvoiceService._();
  static final instance = InvoiceService._();
  final _dio = ApiClient.instance.dio;

  // Stale-while-revalidate screen cache — see MachineService for the full
  // reasoning. cachedDefaultList only covers the unfiltered query.
  static List<Invoice>? cachedDefaultList;
  static final Map<int, Invoice> cachedById = {};
  static Map<String, dynamic>? cachedRevenueSummary;
  static List<Map<String, dynamic>>? cachedRevenueByHospital;

  Future<List<Invoice>> list({String? status, String? search, int? salesOrderId, int? machineId}) async {
    final res = await _dio.get('/invoices', queryParameters: {
      'status':          ?status,
      'search':          ?search,
      'sales_order_id':  ?salesOrderId,
      'machine_id':      ?machineId,
    });
    final (data, _) = ApiClient.unwrapList(res);
    final invoices = data.map((j) => Invoice.fromJson(j as Map<String, dynamic>)).toList();
    if (status == null && search == null && salesOrderId == null && machineId == null) {
      cachedDefaultList = invoices;
    }
    return invoices;
  }

  Future<Invoice> get(int id) async {
    final res = await _dio.get('/invoices/$id');
    final invoice = Invoice.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    cachedById[invoice.id] = invoice;
    return invoice;
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
      if (raw is Map<String, dynamic>) { cachedRevenueSummary = raw; return raw; }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Returns a signed, no-login-required URL to the invoice PDF — valid 7 days.
  /// Used for external sharing (WhatsApp etc.), not for in-app downloads.
  Future<String> shareLink(int id) async {
    final res = await _dio.post('/invoices/$id/share-link');
    final data = ApiClient.unwrap(res) as Map<String, dynamic>;
    return data['share_url'] as String;
  }

  Future<List<int>> pdfBytes(int id) async {
    final res = await _dio.get<List<int>>('/invoices/$id/pdf', options: Options(responseType: ResponseType.bytes));
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> revenueByHospital() async {
    try {
      final res = await _dio.get('/revenue/by-hospital');
      final (data, _) = ApiClient.unwrapList(res);
      final list = data.whereType<Map<String, dynamic>>().toList();
      cachedRevenueByHospital = list;
      return list;
    } catch (_) {
      return [];
    }
  }
}
