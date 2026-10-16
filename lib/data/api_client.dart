import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Error del API con código de estado.
class ApiException implements Exception {
  ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// Cliente HTTP contra el API Gateway. Añade `x-api-key` cuando hay una
/// llave de kiosco configurada (pedidos sin JWT).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (AppConfig.kioskApiKey.isNotEmpty) 'x-api-key': AppConfig.kioskApiKey,
      };

  Future<dynamic> get(String path) => _send(() => _client.get(_uri(path), headers: _headers()));

  Future<dynamic> post(String path, Object body) =>
      _send(() => _client.post(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Future<dynamic> put(String path, Object body) =>
      _send(() => _client.put(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Uri _uri(String path) => Uri.parse('${AppConfig.apiUrl}$path');

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final res = await request().timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var message = 'Error ${res.statusCode}';
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        message = '${j['message'] ?? j['error'] ?? message}';
      } catch (_) {
        // respuesta sin cuerpo JSON
      }
      throw ApiException(message, res.statusCode);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
