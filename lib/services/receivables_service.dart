import 'api_client.dart';

/// Credit sales / hire purchase tracking (GET /receivables, statement,
/// lump "Pay due"). Plain maps — these are report shapes, not entities.
class ReceivablesService {
  ReceivablesService._();
  static final instance = ReceivablesService._();
  final _dio = ApiClient.instance.dio;

  static Map<String, dynamic>? cachedDefault;

  /// {summary: {...}, data: [customer rows]}
  Future<Map<String, dynamic>> list({String? search, String? dateFrom, String? dateTo}) async {
    final res = await _dio.get('/receivables', queryParameters: {
      'search': ?search,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
    });
    final body = Map<String, dynamic>.from(res.data as Map);
    if (search == null) cachedDefault = body;
    return body;
  }

  Future<Map<String, dynamic>> statement({int? hospitalId, String? clientName, String? dateFrom, String? dateTo}) async {
    final res = await _dio.get('/receivables/statement', queryParameters: {
      'hospital_id': ?hospitalId,
      'client_name': ?(hospitalId == null ? clientName : null),
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Lump payment applied to the customer's oldest invoices first.
  Future<Map<String, dynamic>> pay({
    int? hospitalId,
    String? clientName,
    required int amount,
    required String method,
    required String paidAt,
    String? reference,
    String? notes,
  }) async {
    final res = await _dio.post('/receivables/pay', data: {
      'hospital_id': ?hospitalId,
      'client_name': ?(hospitalId == null ? clientName : null),
      'amount': amount,
      'payment_method': method,
      'paid_at': paidAt,
      'reference': ?reference,
      'notes': ?notes,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
