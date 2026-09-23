import '../models/part_cannibalization.dart';
import 'api_client.dart';

class PartCannibalizationService {
  PartCannibalizationService._();
  static final instance = PartCannibalizationService._();
  final _dio = ApiClient.instance.dio;

  // Stale-while-revalidate screen cache — see MachineService for the full
  // reasoning. cachedDefaultList only covers the unfiltered query.
  static List<PartCannibalization>? cachedDefaultList;

  Future<List<PartCannibalization>> list({String? status, int? sourceSerialNumberId}) async {
    final res = await _dio.get('/part-cannibalizations', queryParameters: {
      'status': ?status,
      'source_serial_number_id': ?sourceSerialNumberId,
    });
    final (data, _) = ApiClient.unwrapList(res);
    final records = data.map((j) => PartCannibalization.fromJson(j as Map<String, dynamic>)).toList();
    if (status == null && sourceSerialNumberId == null) cachedDefaultList = records;
    return records;
  }

  Future<PartCannibalization> orderReplacement(int id, {int? purchaseOrderId}) async {
    final res = await _dio.post('/part-cannibalizations/$id/order-replacement', data: {
      'purchase_order_id': purchaseOrderId,
    });
    return PartCannibalization.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<PartCannibalization> resolve(int id) async {
    final res = await _dio.post('/part-cannibalizations/$id/resolve');
    return PartCannibalization.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
