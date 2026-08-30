import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/photo_models.dart';
import 'async_state.dart';

class PhotoAlbumController extends ChangeNotifier with AsyncState {
  PhotoAlbumController(this._api) {
    load();
  }

  final ApiClient _api;

  String _tab = 'Recientes';
  String get tab => _tab;

  List<PhotoAlbum> albums = const [];
  List<Photo> photos = const [];

  Future<void> load() => run(() async {
        final favoritos = _tab == 'Favoritos';
        final results = await Future.wait([
          _api.get('/fotos/albumes'),
          _api.get('/fotos', query: {
            if (favoritos) 'favoritos': 'true',
          }),
        ]);
        albums = [
          for (var i = 0; i < (results[0] as List).length; i++)
            PhotoAlbum.fromApi(
                Map<String, dynamic>.from((results[0] as List)[i] as Map), i),
        ];
        photos = [
          for (var i = 0; i < (results[1] as List).length; i++)
            Photo.fromApi(
                Map<String, dynamic>.from((results[1] as List)[i] as Map), i),
        ];
      });

  void setTab(String tab) {
    _tab = tab;
    load();
  }
}
