import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/photo_models.dart';
import 'async_state.dart';

/// Álbum de fotos del Home.
///
/// El servicio guarda cada imagen direccionada por su contenido y genera las
/// miniaturas; la app pide URLs y las dibuja. Como los widgets de imagen
/// descargan por su cuenta, esas URLs llevan el token en la cadena de consulta.
class PhotoAlbumController extends ChangeNotifier with AsyncState {
  PhotoAlbumController(this._api) {
    load();
  }

  final Api _api;

  String _tab = 'Recientes';
  String get tab => _tab;

  List<PhotoAlbum> albums = const [];
  List<Photo> photos = const [];

  Future<void> load() => run(() async {
        final fAlbumes = _api.fotos.albumes();
        // "Favoritos" no es un campo del servicio: es una etiqueta. Marcar una
        // foto es etiquetarla, y así el favorito también se ve desde la web.
        final fFotos = _tab == 'Favoritos'
            ? _api.fotos.favoritas()
            : _api.fotos.fotos();

        final as = await fAlbumes;
        albums = [for (var i = 0; i < as.length; i++) PhotoAlbum.fromApi(as[i], i)];

        final fs = await fFotos;
        photos = [for (var i = 0; i < fs.length; i++) Photo.fromApi(fs[i], i)];
      });

  void setTab(String tab) {
    _tab = tab;
    load();
  }
}
