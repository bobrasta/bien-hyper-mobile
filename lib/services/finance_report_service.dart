import 'api_client.dart';

class FinanceReportService {
  FinanceReportService._();
  static final instance = FinanceReportService._();
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> _get(String path, {String? dateFrom, String? dateTo}) async {
    final res = await _dio.get(path, queryParameters: {
      'date_from': ?dateFrom,
      'date_to':   ?dateTo,
    });
    final raw = ApiClient.unwrap(res);
    return raw is Map<String, dynamic> ? raw : {};
  }

  Future<Map<String, dynamic>> vat({String? dateFrom, String? dateTo}) =>
      _get('/finance-reports/vat', dateFrom: dateFrom, dateTo: dateTo);

  Future<Map<String, dynamic>> profitLoss({String? dateFrom, String? dateTo}) =>
      _get('/finance-reports/profit-loss', dateFrom: dateFrom, dateTo: dateTo);

  Future<Map<String, dynamic>> trialBalance() => _get('/finance-reports/trial-balance');

  Future<Map<String, dynamic>> balanceSheet() => _get('/finance-reports/balance-sheet');

  Future<Map<String, dynamic>> arAging() => _get('/finance-reports/ar-aging');

  Future<Map<String, dynamic>> cashFlow({String? dateFrom, String? dateTo}) =>
      _get('/finance-reports/cash-flow', dateFrom: dateFrom, dateTo: dateTo);
}
