import '../models/disciplinary_case.dart';
import 'api_client.dart';

export '../models/disciplinary_case.dart';

class DisciplinaryCaseService {
  DisciplinaryCaseService._();
  static final instance = DisciplinaryCaseService._();
  final _dio = ApiClient.instance.dio;

  Future<List<DisciplinaryCase>> list(int userId) async {
    final res = await _dio.get('/staff/$userId/disciplinary-cases');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => DisciplinaryCase.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<DisciplinaryCase> create(int userId, Map<String, dynamic> data) async {
    final res = await _dio.post('/staff/$userId/disciplinary-cases', data: data);
    return DisciplinaryCase.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<DisciplinaryCaseNote> addNote(int caseId, String note) async {
    final res = await _dio.post('/disciplinary-cases/$caseId/notes', data: {'note': note});
    return DisciplinaryCaseNote.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<DisciplinaryCase> advance(int caseId, {String? actionTaken}) async {
    final res = await _dio.post('/disciplinary-cases/$caseId/advance', data: {
      'action_taken': ?actionTaken,
    });
    return DisciplinaryCase.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<DisciplinaryCase> close(int caseId) async {
    final res = await _dio.post('/disciplinary-cases/$caseId/close');
    return DisciplinaryCase.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }
}
