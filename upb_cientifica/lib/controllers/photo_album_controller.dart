import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/photo_models.dart';
import 'async_state.dart';

/// Estado del álbum y sus filtros; descarta respuestas de búsquedas anteriores.
class PhotoAlbumController extends ChangeNotifier with AsyncState {
  PhotoAlbumController(this._api) {
    load();
  }
  final Api _api;
  String _tab = 'Recientes';
  String get tab => _tab;
  String busqueda = '';
  String? albumId;
  String? etiqueta;
  List<String> etiquetas = [];
  List<PhotoAlbum> albums = [];
  List<Photo> photos = [];
  Timer? _espera;
  int _version = 0;
  bool _cerrado = false;
  Future<void>? _carga;
  bool _pendiente = false;

  PhotoAlbum? get albumSeleccionado {
    for (final album in albums) {
      if (album.id == albumId) return album;
    }
    return null;
  }

  @override
  void notifyListeners() {
    if (!_cerrado) super.notifyListeners();
  }

  Future<void> load() {
    _version++;
    _pendiente = true;
    return _carga ??=
        run(() async {
          while (_pendiente && !_cerrado) {
            _pendiente = false;
            final version = _version;
            try {
              final resultado = await Future.wait([
                _api.fotos.albumes(),
                _api.fotos.fotos(
                  albumId: albumId,
                  etiqueta: etiqueta,
                  q: busqueda,
                ),
                _api.fotos.etiquetas(),
              ]);
              if (_cerrado || version != _version) continue;
              final lista = resultado[0] as List<Map<String, dynamic>>;
              albums = [
                for (var i = 0; i < lista.length; i++)
                  PhotoAlbum.fromApi(lista[i], i),
              ];
              final imagenes = resultado[1] as List<Map<String, dynamic>>;
              photos = [
                for (var i = 0; i < imagenes.length; i++)
                  Photo.fromApi(imagenes[i], i),
              ].where((f) => _tab != 'Favoritos' || f.favorite).toList();
              etiquetas = resultado[2] as List<String>;
            } catch (_) {
              if (!_cerrado && version == _version) rethrow;
            }
          }
        }).whenComplete(() {
          _carga = null;
        });
  }

  void buscar(String texto) {
    busqueda = texto;
    _version++;
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), load);
  }

  void seleccionarAlbum(String? id) {
    albumId = id;
    load();
  }

  void seleccionarEtiqueta(String? valor) {
    etiqueta = valor;
    load();
  }

  void setTab(String tab) {
    _tab = tab;
    load();
  }

  Future<void> actualizar(
    Photo foto,
    String titulo,
    String descripcion,
    List<String> etiquetas,
  ) async {
    await _api.fotos.actualizar(
      foto.id,
      titulo: titulo,
      descripcion: descripcion,
      etiquetas: etiquetas,
    );
    if (!_cerrado) await load();
  }

  Future<PhotoAlbum> compartir(
    String id,
    String correo, {
    required bool conceder,
  }) async =>
      _reemplazar(await _api.fotos.compartir(id, correo, conceder: conceder));
  Future<PhotoAlbum> publicar(String id, {required bool activo}) async =>
      _reemplazar(await _api.fotos.publicar(id, activo: activo));
  PhotoAlbum _reemplazar(Map<String, dynamic> datos) {
    final indice = albums.indexWhere((a) => a.id == datos['id']);
    final album = PhotoAlbum.fromApi(datos, indice < 0 ? 0 : indice);
    if (!_cerrado && indice >= 0) {
      albums[indice] = album;
      notifyListeners();
    }
    return album;
  }

  @override
  void dispose() {
    _cerrado = true;
    _version++;
    _espera?.cancel();
    super.dispose();
  }
}
