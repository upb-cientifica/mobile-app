import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Qué alertas ya vio esta persona en este dispositivo.
///
/// El Monitoreo no guarda "leída", y hace bien: una alerta disparada es un
/// hecho del sistema, mientras que haberla leído es de cada persona en cada
/// teléfono. Ningún servicio del sistema es dueño de ese dato, así que vive
/// aquí.
///
/// Se apoya en el mismo almacén que los tokens por no arrastrar otra
/// dependencia; no es información sensible, sólo local.
class AlertasLeidas {
  AlertasLeidas([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _clave = 'upb.alertas_leidas';

  /// Tope de identificadores guardados. Las alertas viejas caducan solas
  /// cuando el Monitoreo deja de reportarlas, así que no hace falta más.
  static const int _tope = 300;

  Set<String>? _cache;

  Future<Set<String>> leidas() async {
    if (_cache != null) return _cache!;
    try {
      final crudo = await _storage.read(key: _clave);
      final lista = crudo == null ? const [] : jsonDecode(crudo) as List;
      _cache = lista.map((e) => '$e').toSet();
    } catch (_) {
      _cache = <String>{};
    }
    return _cache!;
  }

  Future<void> marcar(Iterable<String> ids) async {
    final actuales = await leidas();
    actuales.addAll(ids);
    // Se conservan las últimas: el orden de inserción del Set lo garantiza.
    final recortadas = actuales.length <= _tope
        ? actuales
        : actuales.skip(actuales.length - _tope).toSet();
    _cache = recortadas;
    await _storage.write(key: _clave, value: jsonEncode(recortadas.toList()));
  }

  Future<void> limpiar() async {
    _cache = <String>{};
    await _storage.delete(key: _clave);
  }
}
