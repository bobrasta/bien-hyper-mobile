import '../models/spare_part.dart';
import 'api_client.dart';

class SparePartService {
  SparePartService._();
  static final instance = SparePartService._();
  final _dio = ApiClient.instance.dio;

  // Stale-while-revalidate screen cache — see MachineService for the full
  // reasoning. cachedDefaultList only covers the unfiltered query.
  static List<SparePart>? cachedDefaultList;
  static final Map<int, SparePart> cachedById = {};

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
      // Same reasoning as InventoryService.list() — callers (POS catalog/scan,
      // Add Part dialog) need the whole catalog, not the backend's default
      // 20-per-page page.
      'per_page': 1000,
    });
    final (data, _) = ApiClient.unwrapList(res);
    final parts = data.map((j) => SparePart.fromJson(j as Map<String, dynamic>)).toList();
    if (category == null && lowStock != true && supplier == null && search == null) {
      cachedDefaultList = parts;
    }
    return parts;
  }

  Future<SparePart> get(int id) async {
    final res = await _dio.get('/inventory/$id');
    final part = SparePart.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    cachedById[part.id] = part;
    return part;
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
