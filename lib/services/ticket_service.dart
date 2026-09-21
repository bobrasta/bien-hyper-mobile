import 'package:dio/dio.dart';

import '../models/service_ticket.dart';
import 'api_client.dart';

class TicketService {
  TicketService._();
  static final instance = TicketService._();
  final _dio = ApiClient.instance.dio;

  Future<List<ServiceTicket>> list({String? status, String? hospital, int? machineId, int? assignedTo, bool noCache = false}) async {
    final res = await _dio.get('/tickets',
      queryParameters: {
        'status': ?status,
        'hospital': ?hospital,
        'machine_id': ?machineId,
        'assigned_to': ?assignedTo,
        'per_page': 120,
      },
      options: noCache ? ApiClient.noCache : null,
    );
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => ServiceTicket.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ServiceTicket> get(int id) async {
    final res = await _dio.get('/tickets/$id');
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<ServiceTicket> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/tickets', data: data);
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<ServiceTicket> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/tickets/$id', data: data);
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<ServiceTicket> addPart(int id, {
    required int inventoryItemId,
    required int qty,
    int? unitCost,
    int? sourceSerialNumberId,
  }) async {
    final res = await _dio.post('/tickets/$id/parts', data: {
      'inventory_item_id': inventoryItemId,
      'qty': qty,
      'unit_cost': unitCost,
      'source_serial_number_id': sourceSerialNumberId,
    });
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> resolve(int id, {String? resolutionNotes}) =>
      _dio.post('/tickets/$id/resolve', data: {
        if (resolutionNotes != null && resolutionNotes.isNotEmpty)
          'resolution_notes': resolutionNotes,
      });

  Future<ServiceTicket> overrideBilling(int id, {required String billingStatus, required String reason}) async {
    final res = await _dio.post('/tickets/$id/override-billing', data: {
      'billing_status': billingStatus,
      'reason': reason,
    });
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<ServiceTicket> acknowledge(int id) async {
    final res = await _dio.post('/tickets/$id/acknowledge');
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  // Stage tracker (technician dashboard) — advances the ticket to the next
  // step: assigned -> travelling -> on_site -> repair -> signed_off.
  Future<ServiceTicket> advanceStage(int id, String nextStage) async {
    final res = await _dio.post('/tickets/$id/advance-stage', data: {'stage': nextStage});
    return ServiceTicket.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/tickets/$id');

  Future<TicketAttachment> uploadAttachment(int ticketId, String filePath, String fileName, {String? category}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'category': ?category,
    });
    final res = await _dio.post('/tickets/$ticketId/attachments', data: formData);
    return TicketAttachment.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteAttachment(int ticketId, int attachmentId) =>
      _dio.delete('/tickets/$ticketId/attachments/$attachmentId');
}
