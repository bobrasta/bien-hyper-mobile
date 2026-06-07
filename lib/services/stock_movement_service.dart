import '../models/stock_movement.dart';
import 'api_client.dart';

class StockMovementService {
  StockMovementService._();
  static final instance = StockMovementService._();
  final _dio = ApiClient.instance.dio;

  Future<List<StockMovement>> list({int? inventoryItemId, String? type}) async {
    final res = await _dio.get('/stock-movements', queryParameters: {
      'inventory_item_id': ?inventoryItemId,
      'type':              ?type,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => StockMovement.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<StockMovement> record({
    required int inventoryItemId,
    required String type,
    required int quantity,
    int?    unitCost,
    String? currency,
    String? notes,
    String? batchNumber,
    String? expiryDate,
  }) async {
    final res = await _dio.post('/stock-movements', data: {
      'inventory_item_id': inventoryItemId,
      'type':              type,
      'quantity':          quantity,
      'unit_cost':    ?unitCost,
      'currency':     ?currency,
      'notes':        ?notes,
      'batch_number': ?batchNumber,
      'expiry_date':  ?expiryDate,
    });
    return StockMovement.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
