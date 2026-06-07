import '../models/quotation.dart';
import 'api_client.dart';

class QuotationService {
  QuotationService._();
  static final instance = QuotationService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Quotation>> list({String? status, String? search}) async {
    final res = await _dio.get('/quotations', queryParameters: {
      'status': ?status,
      'search': ?search,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Quotation.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Quotation> get(int id) async {
    final res = await _dio.get('/quotations/$id');
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Quotation> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/quotations', data: data);
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Quotation> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/quotations/$id', data: data);
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/quotations/$id');

  Future<Quotation> send(int id) async {
    final res = await _dio.post('/quotations/$id/send');
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Quotation> accept(int id) async {
    final res = await _dio.post('/quotations/$id/accept');
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Quotation> reject(int id) async {
    final res = await _dio.post('/quotations/$id/reject');
    return Quotation.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> convert(int id, {String? expectedDeliveryDate, String? notes}) async {
    final res = await _dio.post('/quotations/$id/convert', data: {
      'expected_delivery_date': ?expectedDeliveryDate,
      'notes':                  ?notes,
    });
    return ApiClient.unwrap(res) as Map<String, dynamic>;
  }
}
