import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/video_item.dart';
import 'async_state.dart';

/// Catálogo de video. El servicio ya devuelve sólo lo que el usuario puede ver,
/// según su grupo y el nivel de acceso de cada video.
class StreamingController extends ChangeNotifier with AsyncState {
  StreamingController(this._api) {
    load();
  }

  final Api _api;

  List<VideoItem> videos = const [];

  Future<void> load() => run(() async {
        final list = await _api.video.videos();
        videos = [for (var i = 0; i < list.length; i++) VideoItem.fromApi(list[i], i)];
      });

  /// Manifiesto HLS del video, o null si todavía se está empaquetando.
  Future<String?> manifestUrl(String videoId) => _api.video.manifiesto(videoId);
}
