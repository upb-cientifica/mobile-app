import 'package:flutter/foundation.dart';

import '../data/api.dart';
import 'async_state.dart';

/// Detalle de un archivo del Home: metadatos, quién tiene acceso, permisos
/// Unix y versiones.
///
/// El identificador del archivo **es su ruta**: así lo nombra el Shared File
/// Server, y así se pide todo lo de esta pantalla.
class FileDetailController extends ChangeNotifier with AsyncState {
  FileDetailController(this._api, this.ruta) {
    load();
  }

  final Api _api;
  final String ruta;

  String nombre = '';
  String tipo = 'otro';
  int tamanoBytes = 0;
  String propietario = '';
  String grupo = '';
  String modificadoEn = '';
  int version = 0;
  String octal = '640';

  /// Con quién está compartido: `{correo, permiso}`.
  List<Map<String, dynamic>> compartidoCon = const [];

  /// Historial de versiones que guarda el servicio.
  List<Map<String, dynamic>> versiones = const [];

  /// Los tres tríos rwx, en el orden propietario / grupo / otros.
  List<List<bool>> permisos = [
    [true, true, false],
    [true, false, false],
    [false, false, false],
  ];

  static const List<String> roles = ['Propietario', 'Grupo', 'Otros'];

  bool _sucio = false;
  bool get hayCambios => _sucio;

  /// Sólo el dueño o un administrador puede tocar los permisos; el servicio lo
  /// rechazaría de todos modos, pero conviene no ofrecer lo que no se puede.
  bool puedeEditar = false;

  String get carpeta {
    final i = ruta.lastIndexOf('/');
    return i <= 0 ? '/' : ruta.substring(0, i);
  }

  Future<void> load() => run(() async {
        // Los metadatos del nodo salen del listado de su carpeta: el servicio
        // no publica un endpoint de "detalle" por nodo.
        final fPerm = _api.archivos.permisos(ruta);
        final fVers = _api.archivos.versiones(ruta);
        final fPadre = _api.archivos.listar(carpeta);

        final p = await fPerm;
        propietario = '${p['propietario'] ?? ''}';
        grupo = '${p['grupo'] ?? ''}';
        compartidoCon = (p['compartidoCon'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final perm = Map<String, dynamic>.from(p['permisos'] as Map? ?? {});
        octal = '${perm['octal'] ?? '640'}';
        permisos = [
          _trio(perm['propietario']),
          _trio(perm['grupo']),
          _trio(perm['otros']),
        ];

        versiones = await fVers;

        final hermanos = await fPadre;
        final yo = [...hermanos.archivos, ...hermanos.carpetas]
            .where((n) => n['ruta'] == ruta)
            .firstOrNull;
        if (yo != null) {
          nombre = '${yo['nombre']}';
          tipo = '${yo['tipo']}';
          tamanoBytes = (yo['tamanoBytes'] as num?)?.toInt() ?? 0;
          modificadoEn = '${yo['modificadoEn'] ?? ''}';
          version = (yo['version'] as num?)?.toInt() ?? 0;
        } else {
          nombre = ruta.substring(ruta.lastIndexOf('/') + 1);
        }

        _sucio = false;
      });

  /// Marca el usuario de la sesión como dueño para habilitar la edición.
  void establecerUsuario(String correo, {bool esAdmin = false}) {
    final nuevo = esAdmin || correo == propietario;
    if (nuevo != puedeEditar) {
      puedeEditar = nuevo;
      notifyListeners();
    }
  }

  void alternar(int rol, int bit) {
    if (!puedeEditar) return;
    permisos[rol][bit] = !permisos[rol][bit];
    _sucio = true;
    notifyListeners();
  }

  /// Modo octal que resultaría de lo marcado ahora mismo.
  String get octalPropuesto =>
      '${_digito(permisos[0])}${_digito(permisos[1])}${_digito(permisos[2])}';

  Future<void> guardarPermisos() async {
    await _api.archivos.cambiarPermisos(
      ruta,
      owner: _digito(permisos[0]),
      group: _digito(permisos[1]),
      others: _digito(permisos[2]),
    );
    await load();
  }

  Future<void> dejarDeCompartir(String correo) async {
    await _api.archivos.dejarDeCompartir(ruta, correo);
    await load();
  }

  Future<void> compartir(String correo, String permiso) async {
    await _api.archivos.compartir(ruta, correo, permiso: permiso);
    await load();
  }

  /// URL de descarga con el token incrustado.
  Future<String> urlDescarga() => _api.archivos.urlDescarga(ruta);

  static List<bool> _trio(dynamic v) {
    final m = v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    return [
      m['lectura'] == true,
      m['escritura'] == true,
      m['ejecucion'] == true,
    ];
  }

  static int _digito(List<bool> trio) =>
      (trio[0] ? 4 : 0) + (trio[1] ? 2 : 0) + (trio[2] ? 1 : 0);
}
