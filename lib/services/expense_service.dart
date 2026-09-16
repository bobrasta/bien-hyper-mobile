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

  Future<Expense> approve(int id) async {
    final res = await _dio.post('/expenses/$id/approve');
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> escalate(int id, {String? reason}) async {
    final res = await _dio.post('/expenses/$id/escalate', data: {'escalation_reason': reason});
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> reject(int id, {String? reason}) async {
    final res = await _dio.post('/expenses/$id/reject', data: {'rejection_reason': reason});
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> initiatePayment(int id, {String? paymentMethod, String? reference}) async {
    final res = await _dio.post('/expenses/$id/initiate-payment', data: {
      'payment_method':    paymentMethod,
      'payment_reference': reference,
    });
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> markPaid(int id) async {
    final res = await _dio.post('/expenses/$id/mark-paid');
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Expense> stopRecurring(int id) async {
    final res = await _dio.post('/expenses/$id/stop-recurring');
    return Expense.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> setCategoryRequiresDirector(int categoryId, bool value) =>
      _dio.put('/expense-categories/$categoryId', data: {'requires_director_approval': value});

  Future<ExpenseCategory> createCategory(Map<String, dynamic> data) async {
    final res = await _dio.post('/expense-categories', data: data);
    return ExpenseCategory.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  // data may explicitly include 'parent_id': null to move a subcategory
  // back to top-level — pass a plain map (not the ?-omit convenience) so
  // an explicit null actually reaches the server as null, not omitted.
  Future<ExpenseCategory> updateCategoryDetails(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/expense-categories/$id', data: data);
    return ExpenseCategory.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) => _dio.delete('/expense-categories/$id');
}
