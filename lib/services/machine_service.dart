import '../models/machine.dart';
import 'api_client.dart';

class MachineService {
  MachineService._();
  static final instance = MachineService._();
  final _dio = ApiClient.instance.dio;

  // Widget-level stale-while-revalidate cache, on top of (not instead of)
  // ApiClient's HTTP-response cache below — the HTTP cache already makes a
  // repeat fetch fast, but MachineListScreen/MachineDetailScreen still
  // blanked to a loading spinner on every navigation regardless of how
  // fast that fetch resolved, since they gated the whole body on `_loading`
  // alone rather than "do I have something to show already." These two
  // static fields let a freshly-mounted screen instance show the last-known
  // data immediately (surviving widget disposal, unlike State fields) while
  // a real refresh happens silently in the background. Deliberately scoped
  // to only the DEFAULT/unfiltered list — a filtered query showing stale
  // data from a different filter would be actively misleading, so filter
  // changes still show the normal loading state.
  static List<Machine>? cachedDefaultList;
  static final Map<int, Machine> cachedById = {};

  Future<List<Machine>> list({
    String? status,
    int? hospitalId,
    String? type,
    String? model,
    String? zone,
    bool? replacementRecommended,
  }) async {
    final res = await _dio.get('/machines',
      queryParameters: {
        'status':      ?status,
        'hospital_id': ?hospitalId,
        'type':        ?type,
        'model':       ?model,
        'zone':        ?zone,
        if (replacementRecommended == true) 'replacement_recommended': 1,
        'per_page':    500,
      },
      options: ApiClient.cachingOptions(const Duration(minutes: 1)),
    );
    final (data, _) = ApiClient.unwrapList(res);
    final machines = data.map((j) => Machine.fromJson(j as Map<String, dynamic>)).toList();
    if (status == null && hospitalId == null && type == null && model == null &&
        zone == null && replacementRecommended != true) {
      cachedDefaultList = machines;
    }
    return machines;
  }

  // Section 13
  Future<List<Machine>> inStock() async {
    final res = await _dio.get('/machines/in-stock');
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Machine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Machine> receive(Map<String, dynamic> data) async {
    final res = await _dio.post('/machines/receive', data: data);
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Machine> allocate(int id, {required int hospitalId, String? reason}) async {
    final res = await _dio.post('/machines/$id/allocate', data: {
      'hospital_id': hospitalId,
      'reason': ?reason,
    });
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  // Section 12
  Future<Map<String, dynamic>> costs(int id) async {
    final res = await _dio.get('/machines/$id/costs');
    return ApiClient.unwrap(res) as Map<String, dynamic>;
  }

  Future<Machine> get(int id) async {
    final res = await _dio.get('/machines/$id');
    final machine = Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    cachedById[machine.id] = machine;
    return machine;
  }

  Future<Machine> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/machines', data: data);
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Machine> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/machines/$id', data: data);
    return Machine.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/machines/$id');
}
