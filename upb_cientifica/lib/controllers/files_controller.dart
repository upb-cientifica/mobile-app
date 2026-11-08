import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/api.dart';
import '../models/file_models.dart';
import 'async_state.dart';

enum FilesViewMode { grid, list }

/// Explorador del Home compartido: navegación por rutas, filtro y vista.
///
/// El servicio identifica cada nodo por su **ruta**, no por un id opaco, así
/// que aquí la ruta es el identificador: es única, estable y lleva el padre
/// implícito.
class FilesController extends ChangeNotifier with AsyncState {
  FilesController(this._api) {
    load();
  }

  final Api _api;

  FilesViewMode _viewMode = FilesViewMode.list;
  String _filter = 'Todos';
  int? _openMenuIndex;
  String _path = '/';
  bool _enPapelera = false;

  List<FolderEntry> folders = const [];
  List<FileEntry> files = const [];

  FilesViewMode get viewMode => _viewMode;
  String get filter => _filter;
  int? get openMenuIndex => _openMenuIndex;
  String get path => _path;
  bool get enPapelera => _enPapelera;
  List<String> get breadcrumb => _enPapelera
      ? const ['Papelera']
      : ['Inicio', ..._path.split('/').where((s) => s.isNotEmpty)];

  Future<void> load() => run(() async {
        if (_enPapelera) {
          // La papelera es una lista plana: las carpetas guardan todo lo que tenían.
          final c = await _api.archivos.seccion('papelera');
          _path = '/';
          folders = c.carpetas.map(FolderEntry.fromApi).toList();
          files = c.archivos.map(FileEntry.fromApi).toList();
          return;
        }
        final c = await _api.archivos.listar(_path, filtro: fileFilterToApi(_filter));
        _path = c.ruta;
        folders = c.carpetas.map(FolderEntry.fromApi).toList();
        files = c.archivos.map(FileEntry.fromApi).toList();
      });

  void openFolder(FolderEntry folder) {
    _path = folder.path;
    _openMenuIndex = null;
    load();
  }

  /// Entra y sale de la papelera.
  void alternarPapelera() {
    _enPapelera = !_enPapelera;
    _path = '/';
    _openMenuIndex = null;
    load();
  }

  void goTo(int breadcrumbIndex) {
    if (_enPapelera) return;
    if (breadcrumbIndex == 0) {
      _path = '/';
    } else {
      final parts = _path.split('/').where((s) => s.isNotEmpty).toList();
      _path = '/${parts.take(breadcrumbIndex).join('/')}';
    }
    load();
  }

  void setViewMode(FilesViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setFilter(String filter) {
    _filter = filter;
    load();
  }

  void toggleMenu(int index) {
    _openMenuIndex = _openMenuIndex == index ? null : index;
    notifyListeners();
  }

  void closeMenu() {
    if (_openMenuIndex != null) {
      _openMenuIndex = null;
      notifyListeners();
    }
  }

  /// Borrado reversible: el archivo va a la papelera del Home.
  Future<void> deleteFile(String ruta) async {
    await _api.archivos.eliminar(ruta);
    _openMenuIndex = null;
    await load();
  }

  /// Saca de la papelera y lo devuelve a su carpeta.
  Future<void> restore(String ruta) async {
    await _api.archivos.restaurar(ruta);
    _api.archivos.invalidarCache();
    await load();
  }

  /// Borrado de verdad, sin vuelta atrás; una carpeta se va con todo lo suyo.
  Future<void> deletePermanently(String ruta) async {
    await _api.archivos.eliminar(ruta, definitivo: true);
    _api.archivos.invalidarCache();
    await load();
  }

  /// Vacía la papelera. Un elemento que no se pueda borrar no frena a los demás:
  /// al final se avisa de cuáles quedaron.
  Future<void> emptyTrash() async {
    final fallidos = <String>[];
    String? motivo;
    for (final ruta in [...folders.map((f) => f.path), ...files.map((f) => f.id)]) {
      try {
        await _api.archivos.eliminar(ruta, definitivo: true);
      } catch (e) {
        fallidos.add(ruta.split('/').last);
        motivo = '$e';
      }
    }
    _api.archivos.invalidarCache();
    await load();
    if (fallidos.isNotEmpty) {
      throw Exception('No se pudo eliminar ${fallidos.join(', ')}: $motivo');
    }
  }

  /// Descarga a un archivo temporal que quien llama debe guardar y borrar.
  /// Una carpeta llega como ZIP.
  Future<File> downloadToTemp(String ruta, String nombre) async {
    final dir = await getTemporaryDirectory();
    final tmp = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$nombre');
    try {
      await _api.archivos.descargar(ruta, tmp);
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
    return tmp;
  }

  Future<void> toggleStar(String ruta) async {
    await _api.archivos.destacar(ruta);
    _openMenuIndex = null;
    await load();
  }

  Future<void> rename(String ruta, String nuevoNombre) async {
    await _api.archivos.renombrar(ruta, nuevoNombre);
    _openMenuIndex = null;
    await load();
  }

  Future<void> createFolder(String nombre) async {
    await _api.archivos.crearCarpeta(_path, nombre);
    await load();
  }

  /// Sube [bytes] con [filename] a la carpeta actual.
  Future<void> upload(String filename, List<int> bytes) async {
    await _api.archivos.subir(_path, filename, bytes);
    await load();
  }
}
