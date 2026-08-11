import '../models/expense.dart';
import 'api_client.dart';

class ExpenseService {
  ExpenseService._();
  static final instance = ExpenseService._();
  final _dio = ApiClient.instance.dio;

  Future<List<ExpenseCategory>> categories() async {
    final res = await _dio.get('/expense-categories');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => ExpenseCategory.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Expense>> list({int? categoryId, String? paymentMode, String? dateFrom, String? dateTo, String? search}) async {
    final res = await _dio.get('/expenses', queryParameters: {
      'category_id':  ?categoryId,
      'payment_mode': ?paymentMode,
      'date_from':    ?dateFrom,
      'date_to':      ?dateTo,
      'search':       ?search,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Expense> get(int id) async {
    final res = await _dio.get('/expenses/$id');
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/expenses', data: data);
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/expenses/$id', data: data);
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/expenses/$id');
}
