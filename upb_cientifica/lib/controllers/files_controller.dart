import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/file_models.dart';
import 'async_state.dart';

enum FilesViewMode { grid, list }

/// Explorador de archivos: navegación por rutas, filtro, vista y datos del BFF.
class FilesController extends ChangeNotifier with AsyncState {
  FilesController(this._api) {
    load();
  }

  final ApiClient _api;

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
        final j = Map<String, dynamic>.from(await _api.get('/archivos', query: {
          'ruta': _path,
          'filtro': fileFilterToApi(_filter),
        }) as Map);
        _path = j['ruta'] as String? ?? _path;
        folders = (j['carpetas'] as List? ?? [])
            .map((e) => FolderEntry.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
        files = (j['archivos'] as List? ?? [])
            .map((e) => FileEntry.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
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

  Future<void> deleteFile(String id) async {
    await _api.delete('/archivos/$id');
    _openMenuIndex = null;
    await load();
  }

  /// Sube [bytes] con [filename] a la ruta actual (multipart).
  Future<void> upload(String filename, List<int> bytes) async {
    await _api.uploadMultipart(
      '/archivos/upload',
      field: 'archivo',
      filename: filename,
      bytes: bytes,
      fields: {'ruta': _path},
    );
    await load();
  }
}
