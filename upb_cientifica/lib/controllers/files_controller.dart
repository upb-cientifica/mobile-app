import 'package:flutter/foundation.dart';

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

  List<FolderEntry> folders = const [];
  List<FileEntry> files = const [];

  FilesViewMode get viewMode => _viewMode;
  String get filter => _filter;
  int? get openMenuIndex => _openMenuIndex;
  String get path => _path;
  List<String> get breadcrumb =>
      ['Inicio', ..._path.split('/').where((s) => s.isNotEmpty)];

  Future<void> load() => run(() async {
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

  void goTo(int breadcrumbIndex) {
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
