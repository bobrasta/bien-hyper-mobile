import '../models/tax_rate.dart';
import 'api_client.dart';

class TaxRateService {
  TaxRateService._();
  static final instance = TaxRateService._();
  final _dio = ApiClient.instance.dio;

  Future<List<TaxRate>> list() async {
    final res = await _dio.get('/tax-rates');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => TaxRate.fromJson(j as Map<String, dynamic>)).toList();
  }
}
