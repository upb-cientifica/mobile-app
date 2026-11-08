import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../data/api.dart';

/// Reproducción real de un video del servicio de Streaming (HLS).
///
/// El manifiesto entra por el bus; sus segmentos van referenciados de forma
/// relativa, así que resuelven contra esa misma URL y siguen pasando por el
/// bus. El servicio les añade el token al servir la lista, porque el
/// reproductor pide cada segmento sin encabezados.
class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController(this._api, {this.videoId});

  final Api _api;
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
      if (videoId == null) {
        _error = 'No se indicó qué video reproducir.';
        _loading = false;
        notifyListeners();
        return;
      }
      final url = await _api.video.manifiesto(videoId!);
      if (url == null) {
        // El servicio transcodifica con ffmpeg al subir: un video recién
        // publicado todavía no tiene su playlist.
        _error = 'El video aún se está procesando. Inténtalo en unos minutos.';
        _loading = false;
        notifyListeners();
        return;
      }
      final p = VideoPlayerController.networkUrl(Uri.parse(url));
      _player = p;
      p.addListener(notifyListeners);
      await p.initialize();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo reproducir el video: $e';
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
