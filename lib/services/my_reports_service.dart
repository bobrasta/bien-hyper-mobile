import 'package:dio/dio.dart';
import '../models/my_service_report.dart';
import 'api_client.dart';

// Section 7: technician self-service — "own reports" list, already scoped
// server-side to the caller's own ticket assignments (MyReportsController).
class MyReportsService {
  MyReportsService._();
  static final instance = MyReportsService._();
  final _dio = ApiClient.instance.dio;

  Future<List<MyServiceReport>> serviceReports({
    int? hospitalId, int? machineId, String? ticketNumber, String? type,
    String? dateFrom, String? dateTo,
  }) async {
    final res = await _dio.get('/my/service-reports', queryParameters: {
      'hospital_id':   ?hospitalId,
      'machine_id':    ?machineId,
      'ticket_number': ?ticketNumber,
      'type':          ?type,
      'date_from':     ?dateFrom,
      'date_to':       ?dateTo,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => MyServiceReport.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Fetches raw bytes from an attachment's own storage URL (not an API
  /// endpoint) so it can be saved via DownloadManager the same way a
  /// generated PDF is — see utils/pdf_download.dart.
  Future<List<int>> fetchBytes(String url) async {
    final res = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return res.data!;
  }
}
