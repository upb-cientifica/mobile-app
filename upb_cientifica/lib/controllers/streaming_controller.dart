import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/video_item.dart';
import 'async_state.dart';

class StreamingController extends ChangeNotifier with AsyncState {
  StreamingController(this._api) {
    load();
  }

  final ApiClient _api;

  List<VideoItem> videos = const [];

  Future<void> load() => run(() async {
        final list = await _api.get('/streaming/videos') as List;
        videos = [
          for (var i = 0; i < list.length; i++)
            VideoItem.fromApi(Map<String, dynamic>.from(list[i] as Map), i),
        ];
      });

  /// Devuelve la URL de reproducción (HLS) para [videoId].
  Future<String?> manifestUrl(String videoId) async {
    final j = Map<String, dynamic>.from(
        await _api.get('/streaming/videos/$videoId/manifest') as Map);
    return j['url'] as String?;
  }
}
