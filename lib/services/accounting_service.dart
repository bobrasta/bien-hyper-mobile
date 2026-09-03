import '../models/chart_of_account.dart';
import 'api_client.dart';

class AccountCategoryOption {
  const AccountCategoryOption({required this.id, required this.type});
  final int id;
  final String type;

  factory AccountCategoryOption.fromJson(Map<String, dynamic> j) =>
      AccountCategoryOption(id: (j['id'] as num).toInt(), type: j['type'] as String);

  String get label => switch (type) {
    'asset' => 'Asset', 'liability' => 'Liability', 'equity' => 'Equity',
    'revenue' => 'Revenue', 'expense' => 'Expense', _ => type,
  };
}

class AccountingService {
  AccountingService._();
  static final instance = AccountingService._();
  final _dio = ApiClient.instance.dio;

  Future<List<ChartOfAccount>> accounts({String? category, String? status}) async {
    final res = await _dio.get('/accounting/accounts', queryParameters: {
      'category': ?category,
      'status':   ?status,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => ChartOfAccount.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<AccountCategoryOption>> categories() async {
    final res = await _dio.get('/accounting/categories');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => AccountCategoryOption.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ChartOfAccount> createAccount(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/accounts', data: data);
    return ChartOfAccount.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<ChartOfAccount> updateAccount(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/accounting/accounts/$id', data: data);
    return ChartOfAccount.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteAccount(int id) => _dio.delete('/accounting/accounts/$id');

  Future<List<LedgerEntry>> journal() async {
    final res = await _dio.get('/accounting/journal');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => LedgerEntry.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> summary() async {
    final res = await _dio.get('/accounting/summary');
    final raw = ApiClient.unwrap(res);
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> closePeriod() async {
    final res = await _dio.post('/accounting/close-period');
    final raw = ApiClient.unwrap(res);
    return raw is Map<String, dynamic> ? raw : {};
  }
}
