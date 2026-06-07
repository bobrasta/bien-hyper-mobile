import '../models/spare_part.dart';
import 'api_client.dart';

class SparePartService {
  SparePartService._();
  static final instance = SparePartService._();
  final _dio = ApiClient.instance.dio;

  Future<List<SparePart>> list({
    String? category,
    bool? lowStock,
    String? supplier,
    String? search,
  }) async {
    final res = await _dio.get('/inventory', queryParameters: {
      'category':  ?category,
      if (lowStock == true) 'low_stock': 'true',
      'supplier':  ?supplier,
      'search':    ?search,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => SparePart.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<SparePart> get(int id) async {
    final res = await _dio.get('/inventory/$id');
    return SparePart.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SparePart> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/inventory', data: data);
    return SparePart.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<SparePart> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/inventory/$id', data: data);
    return SparePart.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/inventory/$id');

  // Positive qty = add stock, negative = remove stock
  Future<SparePart> adjust(int id, int adjustment, {String reason = ''}) async {
    final res = await _dio.patch('/inventory/$id/adjust', data: {
      'adjustment': adjustment,
      if (reason.isNotEmpty) 'reason': reason,
    });
    return SparePart.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
