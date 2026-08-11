import '../models/inventory_item.dart';
import 'api_client.dart';

class InventoryService {
  InventoryService._();
  static final instance = InventoryService._();
  final _dio = ApiClient.instance.dio;

  Future<List<InventoryItem>> list({
    String? category,
    bool? lowStock,
    String? search,
  }) async {
    final res = await _dio.get('/inventory', queryParameters: {
      'category': ?category,
      if (lowStock == true) 'low_stock': 'true',
      'search':   ?search,
      // Screens that call this load the full catalog once and paginate/filter
      // locally — request it all in one shot rather than the backend's default
      // 20-per-page (which silently truncated the real ~340-item catalog).
      'per_page': 1000,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => InventoryItem.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<InventoryItem> get(int id) async {
    final res = await _dio.get('/inventory/$id');
    return InventoryItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<InventoryItem> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/inventory', data: data);
    return InventoryItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<InventoryItem> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/inventory/$id', data: data);
    return InventoryItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) => _dio.delete('/inventory/$id');
}
