import '../models/chart_of_account.dart';
import 'api_client.dart';

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
