import '../models/invoice.dart';
import '../models/sales_order.dart';
import 'api_client.dart';

sealed class PosCheckoutResult {}

class PosCheckoutInvoice extends PosCheckoutResult {
  PosCheckoutInvoice(this.salesOrder, this.invoice);
  final SalesOrder salesOrder;
  final Invoice invoice;
}

class PosCheckoutPendingApproval extends PosCheckoutResult {
  PosCheckoutPendingApproval(this.salesOrder, this.message);
  final SalesOrder salesOrder;
  final String message;
}

class PosService {
  PosService._();
  static final instance = PosService._();
  final _dio = ApiClient.instance.dio;

  Future<PosCheckoutResult> checkout(Map<String, dynamic> data) async {
    final res = await _dio.post('/pos/checkout', data: data, options: ApiClient.noCache);
    final body = res.data as Map<String, dynamic>;

    if (body['type'] == 'pending_approval') {
      return PosCheckoutPendingApproval(
        SalesOrder.fromJson(body['data'] as Map<String, dynamic>),
        body['message'] as String? ?? 'This sale needs manager approval before it can be completed.',
      );
    }

    return PosCheckoutInvoice(
      SalesOrder.fromJson(body['sales_order'] as Map<String, dynamic>),
      Invoice.fromJson(body['invoice'] as Map<String, dynamic>),
    );
  }
}
