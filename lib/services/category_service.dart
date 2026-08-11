import '../models/category.dart';
import 'api_client.dart';

class CategoryService {
  CategoryService._();
  static final instance = CategoryService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Category>> list({bool includeInactive = false}) async {
    final res = await _dio.get('/categories', queryParameters: {
      if (includeInactive) 'include_inactive': 'true',
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Category.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Category> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/categories', data: data);
    return Category.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Category> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/categories/$id', data: data);
    return Category.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) => _dio.delete('/categories/$id');
}
