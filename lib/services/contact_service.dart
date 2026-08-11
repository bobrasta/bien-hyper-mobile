import '../models/contact.dart';
import 'api_client.dart';

class ContactService {
  ContactService._();
  static final instance = ContactService._();
  final _dio = ApiClient.instance.dio;

  Future<List<Contact>> list({String? hospital, String? tag}) async {
    final res = await _dio.get('/contacts', queryParameters: {
      'hospital': ?hospital,
      'tag': ?tag,
      'per_page': 120,
    });
    final (data, _) = ApiClient.unwrapList(res);
    return data.map((j) => Contact.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Contact> get(int id) async {
    final res = await _dio.get('/contacts/$id');
    return Contact.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Contact> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/contacts', data: data);
    return Contact.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<Contact> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/contacts/$id', data: data);
    return Contact.fromJson(ApiClient.unwrap(res) as Map<String, dynamic>);
  }

  Future<void> addInteraction(int id, Map<String, dynamic> data) =>
      _dio.post('/contacts/$id/interactions', data: data);
}
