import 'package:dio/dio.dart';
import '../storage/token_store.dart';

const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});
  final String message; final int? statusCode; final String? code;
  @override String toString() => message;
}

class ApiClient {
  ApiClient(this.store) {
    dio = Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20), sendTimeout: const Duration(seconds: 20), headers: {'content-type': 'application/json'}));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async { final token = await store.accessToken(); if (token != null && token.isNotEmpty) options.headers['authorization'] = 'Bearer $token'; handler.next(options); }, onError: (error, handler) async { if (error.response?.statusCode == 401 && !_isAuthPath(error.requestOptions.path) && !error.requestOptions.extra.containsKey('retried')) { final refreshed = await _refresh(); if (refreshed) { final request = error.requestOptions..extra['retried'] = true; final token = await store.accessToken(); request.headers['authorization'] = 'Bearer $token'; try { handler.resolve(await dio.fetch(request)); return; } catch (_) { await store.clear(); } } } handler.next(error); }));
  }
  final TokenStore store; late final Dio dio; Future<bool>? _refreshInFlight;
  bool _isAuthPath(String path) => path.contains('/auth/');
  Future<bool> _refresh() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final request = _performRefresh();
    _refreshInFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_refreshInFlight, request)) _refreshInFlight = null;
    }
  }
  Future<bool> _performRefresh() async { final refresh = await store.refreshToken(); if (refresh == null) return false; try { final response = await Dio(BaseOptions(baseUrl: apiBaseUrl)).post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh}); final data = response.data; if (data == null) return false; await store.saveTokens(data['accessToken'] as String, data['refreshToken'] as String); return true; } catch (_) { return false; } }
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _request(() => dio.get<dynamic>(path, queryParameters: query));
  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) => _request(() => dio.post<dynamic>(path, data: data, queryParameters: query));
  Future<dynamic> put(String path, {Object? data}) => _request(() => dio.put<dynamic>(path, data: data));
  Future<dynamic> patch(String path, {Object? data}) => _request(() => dio.patch<dynamic>(path, data: data));
  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) => _request(() => dio.delete<dynamic>(path, queryParameters: query));
  Future<dynamic> _request(Future<Response<dynamic>> Function() request) async { try { final response = await request(); return response.data; } on DioException catch (error) { final data = error.response?.data; final message = data is Map && data['error'] is Map ? (data['error']['message']?.toString() ?? 'Something went wrong.') : 'Network request failed. Check your connection.'; throw ApiException(message, statusCode: error.response?.statusCode); } }
}
