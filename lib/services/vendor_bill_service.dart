import '../models/vendor_bill.dart';
import 'api_client.dart';

class VendorBillService {
  VendorBillService._();
  static final instance = VendorBillService._();
  final _dio = ApiClient.instance.dio;

  Future<List<VendorBill>> list({int? supplierId, String? status, String? search}) async {
    final res = await _dio.get('/vendor-bills', queryParameters: {
      'supplier_id': ?supplierId,
      'status':      ?status,
      'search':      ?search,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => VendorBill.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<VendorBill> get(int id) async {
    final res = await _dio.get('/vendor-bills/$id');
    return VendorBill.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<VendorBill> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/vendor-bills', data: data);
    return VendorBill.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<VendorBill> cancel(int id) async {
    final res = await _dio.post('/vendor-bills/$id/cancel');
    return VendorBill.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<VendorBill> recordPayment(int id, Map<String, dynamic> data) async {
    final res = await _dio.post('/vendor-bills/$id/payments', data: data);
    return VendorBill.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/vendor-bills/$id');
}
