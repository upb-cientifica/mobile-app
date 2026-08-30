import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../data/api_client.dart';

/// Controla la reproducción real de un video servido por el BFF (HLS).
class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController(this._api, {this.videoId});

  final ApiClient _api;
  final String? videoId;

  VideoPlayerController? _player;
  VideoPlayerController? get player => _player;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool get playing => _player?.value.isPlaying ?? false;
  double get progress {
    final v = _player?.value;
    if (v == null || v.duration.inMilliseconds == 0) return 0;
    return v.position.inMilliseconds / v.duration.inMilliseconds;
  }

  Future<void> init() async {
    try {
      String url = 'https://upb.local/streaming/demo/index.m3u8';
      if (videoId != null) {
        final j = Map<String, dynamic>.from(
            await _api.get('/streaming/videos/$videoId/manifest') as Map);
        url = j['url'] as String? ?? url;
      }
      final p = VideoPlayerController.networkUrl(Uri.parse(url));
      _player = p;
      p.addListener(notifyListeners);
      await p.initialize();
      _loading = false;
      notifyListeners();
    } catch (e) {
      // El servicio de Streaming real aún no existe; se muestra el estado de error
      // de la UI (reproductor no disponible) en lugar de un crash.
      _error = 'El servicio de Streaming no está disponible.';
      _loading = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    final p = _player;
    if (p == null) return;
    p.value.isPlaying ? p.pause() : p.play();
  }

  void skip(double deltaFraction) {
    final p = _player;
    if (p == null || p.value.duration == Duration.zero) return;
    final target = p.value.position +
        Duration(
            milliseconds:
                (p.value.duration.inMilliseconds * deltaFraction).round());
    p.seekTo(target);
  }

  void seekTo(double fraction) {
    final p = _player;
    if (p == null || p.value.duration == Duration.zero) return;
    p.seekTo(Duration(
        milliseconds: (p.value.duration.inMilliseconds * fraction).round()));
  }

  @override
  void dispose() {
    _player?.removeListener(notifyListeners);
    _player?.dispose();
    super.dispose();
  }
}
