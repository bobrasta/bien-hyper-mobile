import '../models/purchase_requisition.dart';
import 'api_client.dart';

class PurchaseRequisitionService {
  PurchaseRequisitionService._();
  static final instance = PurchaseRequisitionService._();
  final _dio = ApiClient.instance.dio;

  Future<List<PurchaseRequisition>> list({String? status}) async {
    final res = await _dio.get('/requisitions', queryParameters: {
      'status': ?status,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => PurchaseRequisition.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PurchaseRequisition> get(int id) async {
    final res = await _dio.get('/requisitions/$id');
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseRequisition> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/requisitions', data: data);
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseRequisition> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/requisitions/$id', data: data);
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseRequisition> submit(int id) async {
    final res = await _dio.post('/requisitions/$id/submit');
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseRequisition> approve(int id) async {
    final res = await _dio.post('/requisitions/$id/approve');
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PurchaseRequisition> reject(int id) async {
    final res = await _dio.post('/requisitions/$id/reject');
    return PurchaseRequisition.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/requisitions/$id');
}
