import '../models/credit_note.dart';
import 'api_client.dart';

export '../models/credit_note.dart';

class CreditNoteService {
  CreditNoteService._();
  static final instance = CreditNoteService._();
  final _dio = ApiClient.instance.dio;

  Future<List<CreditNote>> list(int invoiceId) async {
    final res = await _dio.get('/invoices/$invoiceId/credit-notes');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => CreditNote.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<CreditNote> create(int invoiceId, {required String reason, required int amount}) async {
    final res = await _dio.post('/invoices/$invoiceId/credit-notes', data: {'reason': reason, 'amount': amount});
    return CreditNote.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<CreditNote> approve(int id) async {
    final res = await _dio.post('/credit-notes/$id/approve');
    return CreditNote.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<CreditNote> apply(int id) async {
    final res = await _dio.post('/credit-notes/$id/apply');
    return CreditNote.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
