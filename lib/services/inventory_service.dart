import '../models/inventory_item.dart';
import '../models/inventory_item_history.dart';
import 'api_client.dart';

class InventoryService {
  InventoryService._();
  static final instance = InventoryService._();
  final _dio = ApiClient.instance.dio;

  Future<List<InventoryItem>> list({
    String? category,
    bool? lowStock,
    String? search,
    bool? createsMachineRecord,
  }) async {
    final res = await _dio.get('/inventory', queryParameters: {
      'category_id': ?category,
      if (lowStock == true) 'low_stock': 'true',
      'search':   ?search,
      if (createsMachineRecord != null) 'creates_machine_record': createsMachineRecord.toString(),
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

  /// Creates a minimal, uncatalogued item on the fly (e.g. a part discovered
  /// mid-service that isn't in the catalog yet). Flagged `needs_review` so
  /// inventory admin can fill in the real SKU/cost/category later.
  Future<InventoryItem> quickCreate(String name) async {
    final res = await _dio.post('/inventory/quick-create', data: {'name': name});
    return InventoryItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<InventoryItem> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/inventory/$id', data: data);
    return InventoryItem.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) => _dio.delete('/inventory/$id');

  Future<List<SerialHistoryEntry>> history(int id) async {
    final res = await _dio.get('/inventory/$id/history');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => SerialHistoryEntry.fromJson(j as Map<String, dynamic>)).toList();
  }
}
