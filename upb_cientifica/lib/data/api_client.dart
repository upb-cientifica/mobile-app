import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'env.dart';
import 'token_store.dart';

/// Cliente HTTP hacia el BFF.
///
/// - Adjunta `Authorization: Bearer <accessToken>`.
/// - Ante un 401, intenta **una** renovación con el refresh token y reintenta.
/// - Desenvuelve la envoltura `{ "data": ... }` / `{ "error": {...} }`.
class ApiClient {
  ApiClient({TokenStore? tokenStore, http.Client? httpClient})
      : _tokens = tokenStore ?? TokenStore(),
        _http = httpClient ?? http.Client();

  final TokenStore _tokens;
  final http.Client _http;

  /// Se invoca cuando la sesión deja de ser válida (refresh fallido).
  void Function()? onSessionExpired;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send('DELETE', path, query: query);

  /// Envía un archivo como `multipart/form-data`.
  Future<dynamic> uploadMultipart(
    String path, {
    required String field,
    required String filename,
    required List<int> bytes,
    Map<String, String> fields = const {},
    bool retry = true,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path, null))
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    final access = await _tokens.accessToken;
    if (access != null) req.headers['authorization'] = 'Bearer $access';

    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw ApiException('No se pudo subir el archivo.');
    }
    if (res.statusCode == 401 && retry && await _refresh()) {
      return uploadMultipart(path,
          field: field, filename: filename, bytes: bytes, fields: fields, retry: false);
    }
    return _decode(res);
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(Env.apiBaseUrl);
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) q[k] = '$v';
    });
    return base.replace(
      path: '${base.path}$path',
      queryParameters: q.isEmpty ? null : q,
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool retry = true,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{'accept': 'application/json'};
    final access = await _tokens.accessToken;
    if (access != null) headers['authorization'] = 'Bearer $access';

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        req.headers['content-type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 20)),
      );
    } on TimeoutException {
      throw ApiException('La solicitud tardó demasiado. Revisa tu conexión.');
    } catch (e) {
      throw ApiException('No se pudo conectar con el servidor UPB.');
    }

    if (res.statusCode == 401 && retry) {
      if (await _refresh()) {
        return _send(method, path, query: query, body: body, retry: false);
      }
      onSessionExpired?.call();
    }

    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final texto = utf8.decode(res.bodyBytes);
    dynamic json;
    if (texto.isNotEmpty) {
      try {
        json = jsonDecode(texto);
      } catch (_) {/* respuesta no-JSON */}
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    }

    final err = (json is Map) ? json['error'] : null;
    throw ApiException(
      (err is Map ? err['mensaje'] : null)?.toString() ??
          'Error ${res.statusCode}',
      status: res.statusCode,
      codigo: (err is Map ? err['codigo'] : null)?.toString(),
    );
  }

  Future<bool> _refresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _http
          .post(
            _uri('/auth/refresh', null),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes))['data'] as Map;
      await _tokens.save(
        access: data['accessToken'] as String,
        refresh: (data['refreshToken'] ?? refresh) as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _http.close();
}
