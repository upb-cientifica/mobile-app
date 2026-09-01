import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'env.dart';
import 'token_store.dart';

/// Cliente HTTP hacia el **Service Bus**.
///
/// Es el único punto de la app que abre una conexión de red. Toda ruta que pasa
/// por aquí tiene la forma `/{servicio}/{operación}`; el bus resuelve dónde vive
/// ese servicio, comprueba el claim del JWT y traduce el protocolo del destino.
///
/// - Adjunta `Authorization: Bearer <accessToken>`.
/// - Ante un 401, intenta **una** renovación con el refresh token y reintenta.
/// - Desenvuelve la envoltura `{ "data": … }` / `{ "error": {…} }` del bus.
/// - Conserva el `X-Bus-Correlacion` de los errores: con ese número se
///   encuentra el mensaje exacto en la bitácora del bus.
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

  /// El bus pasa los parámetros de consulta al mediador, que los convierte en
  /// elementos del sobre SOAP o en argumentos de la invocación RMI. Por eso la
  /// mayoría de las escrituras viajan en `query` y no en el cuerpo.
  Future<dynamic> post(String path, {Map<String, dynamic>? query, Object? body}) =>
      _send('POST', path, query: query, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? query, Object? body}) =>
      _send('PATCH', path, query: query, body: body);

  Future<dynamic> put(String path, {Map<String, dynamic>? query, Object? body}) =>
      _send('PUT', path, query: query, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send('DELETE', path, query: query);

  /// Sube el contenido de un archivo como cuerpo binario.
  ///
  /// El Home compartido recibe los bytes tal cual —no multipart— y toma el
  /// nombre y la carpeta de la cadena de consulta. El bus reenvía el cuerpo sin
  /// tocarlo, así que el archivo llega íntegro al servicio.
  Future<dynamic> subirArchivo(
    String path, {
    required Map<String, dynamic> query,
    required List<int> bytes,
    bool retry = true,
  }) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/octet-stream',
    };
    final access = await _tokens.accessToken;
    if (access != null) headers['authorization'] = 'Bearer $access';

    http.Response res;
    try {
      final req = http.Request('POST', _uri(path, query))
        ..headers.addAll(headers)
        ..bodyBytes = bytes;
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw ApiException('No se pudo subir el archivo.');
    }
    if (res.statusCode == 401 && retry && await _refresh()) {
      return subirArchivo(path, query: query, bytes: bytes, retry: false);
    }
    return _decode(res);
  }

  /// Encabezados de autenticación para widgets que descargan por su cuenta,
  /// como `Image.network`.
  Future<Map<String, String>> get authHeaders async {
    final access = await _tokens.accessToken;
    return access == null ? const {} : {'authorization': 'Bearer $access'};
  }

  /// Token de acceso vigente. Sirve para construir muchas URLs de descarga sin
  /// volver al almacén seguro por cada una.
  Future<String?> get accessToken => _tokens.accessToken;

  /// URL absoluta a través del bus, con [token] en la cadena de consulta.
  ///
  /// Hace falta para HLS: el reproductor pide los segmentos por su cuenta y no
  /// se puede garantizar que arrastre los encabezados en las dos plataformas.
  /// Tanto el bus como el servicio de Streaming aceptan `?token=` por esto.
  String urlCon(String path, String? token, {Map<String, dynamic>? query}) =>
      _uri(path, {...?query, 'token': ?token}).toString();

  /// Igual que [urlCon], leyendo el token del almacén seguro.
  Future<String> urlConToken(String path, {Map<String, dynamic>? query}) async =>
      urlCon(path, await _tokens.accessToken, query: query);

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(Env.busUrl);
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
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
      throw ApiException('No se pudo conectar con el bus de servicios UPB.');
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
      correlacion: res.headers['x-bus-correlacion'],
    );
  }

  /// Renueva la sesión contra el directorio de usuarios.
  ///
  /// `renovarToken` es una de las dos operaciones que el bus deja pasar sin
  /// token —la otra es `login`—, porque de lo contrario no habría forma de
  /// obtener uno.
  Future<bool> _refresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _http
          .post(
            _uri('/${Servicios.usuarios}/renovarToken', {'refreshToken': refresh}),
            headers: {'accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes))['data'] as Map;
      final nuevo = data['accessToken'] as String?;
      if (nuevo == null || nuevo.isEmpty) return false;
      await _tokens.save(
        access: nuevo,
        refresh: (data['refreshToken'] as String?) ?? refresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _http.close();
}
