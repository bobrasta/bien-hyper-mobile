import '../models/supplier.dart';
import 'api_client.dart';

class SupplierService {
  SupplierService._();
  static final instance = SupplierService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Supplier>> list({String? search, String? type}) async {
    final res = await _dio.get('/suppliers', queryParameters: {
      'search': ?search,
      'type':   ?type,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Supplier.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Supplier> get(int id) async {
    final res = await _dio.get('/suppliers/$id');
    return Supplier.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Supplier> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/suppliers', data: data);
    return Supplier.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Supplier> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/suppliers/$id', data: data);
    return Supplier.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) => _dio.delete('/suppliers/$id');

  Future<void> addItem(int supplierId, Map<String, dynamic> data) =>
      _dio.post('/suppliers/$supplierId/items', data: data);

  Future<void> removeItem(int supplierId, int inventoryItemId) =>
      _dio.delete('/suppliers/$supplierId/items/$inventoryItemId');
}
