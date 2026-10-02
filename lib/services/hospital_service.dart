import '../models/hospital.dart';
import 'api_client.dart';

class HospitalPage {
  final List<Hospital> items;
  final int currentPage;
  final int lastPage;
  final int total;
  const HospitalPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class HospitalService {
  HospitalService._();
  static final instance = HospitalService._();
  final _dio = ApiClient.instance.dio;

  // Stale-while-revalidate screen cache — see MachineService for the full
  // reasoning. Each covers only its own default/unfiltered, page-1 query.
  static List<Hospital>? cachedDefaultList;
  static HospitalPage? cachedFirstPage;
  static final Map<int, Hospital> cachedById = {};

  /// `hasMachines: true` restricts to real client facilities (excludes the
  /// ~13,600 machine-less prospect rows from the national facility registry
  /// import) — pass it for anything fleet/revenue-shaped that only ever
  /// meant "our client sites" by "hospitals". Still capped at 500 and not
  /// paginated, so only safe for callers that genuinely want a small,
  /// bounded set (clients-only lists, dropdowns of real sites) — for the
  /// full directory browse, use [listPaged] instead.
  Future<List<Hospital>> list({String? type, String? region, bool hasMachines = false}) async {
    final res = await _dio.get('/hospitals',
      queryParameters: {
        'type': ?type,
        'region': ?region,
        'has_machines': hasMachines ? 1 : null,
        'per_page': 500,
      },
      options: ApiClient.cachingOptions(const Duration(minutes: 30)),
    );
    final (data, _) = ApiClient.unwrapList(res);
    final hospitals = data.map((j) => Hospital.fromJson(j as Map<String, dynamic>)).toList();
    if (type == null && region == null && hasMachines == false) cachedDefaultList = hospitals;
    return hospitals;
  }

  /// Real server-side pagination over the full hospital directory (now
  /// 13,000+ rows since the national facility registry import) — for the
  /// Hospitals browse screen. Filtering (q/type/region) happens server-side
  /// too, so results and the reported total are always accurate, unlike
  /// [list]'s "load one batch, filter locally" pattern.
  Future<HospitalPage> listPaged({
    int page = 1,
    int perPage = 50,
    String? q,
    String? type,
    String? region,
    String? zone,
    bool hasMachines = false,
  }) async {
    final res = await _dio.get('/hospitals', queryParameters: {
      'page': page,
      'per_page': perPage,
      'q': ?q,
      'type': ?type,
      'region': ?region,
      'zone': ?zone,
      'has_machines': hasMachines ? 1 : null,
    });
    final (data, meta) = ApiClient.unwrapList(res);
    final result = HospitalPage(
      items: data.map((j) => Hospital.fromJson(j as Map<String, dynamic>)).toList(),
      currentPage: (meta?['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta?['last_page'] as num?)?.toInt() ?? page,
      total: (meta?['total'] as num?)?.toInt() ?? data.length,
    );
    if (page == 1 && q == null && type == null && region == null && zone == null && !hasMachines) cachedFirstPage = result;
    return result;
  }

  /// Server-side search for the combobox — never loads the full directory.
  /// See hypermed_claude_code_prompt.md Section 4: the hospital list is
  /// modeled to grow into the thousands (national facility registry).
  Future<List<Hospital>> search(String q) async {
    final res = await _dio.get('/hospitals', queryParameters: {'q': q, 'per_page': 50});
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Hospital.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Hospital> get(int id) async {
    final res = await _dio.get('/hospitals/$id');
    final hospital = Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
    cachedById[hospital.id] = hospital;
    return hospital;
  }

  Future<Hospital> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/hospitals', data: data);
    return Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Hospital> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/hospitals/$id', data: data);
    return Hospital.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('/hospitals/$id');
}
