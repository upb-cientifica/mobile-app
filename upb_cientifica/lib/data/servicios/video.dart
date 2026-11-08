import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Difusión de video: catálogo y reproducción HLS.
class ServicioVideo {
  ServicioVideo(this._api);

  final ApiClient _api;

  static const String _s = Servicios.video;

  static const Map<String, String> _orden = {
    'reciente': 'fecha',
    'titulo': 'titulo',
    'duracion': 'duracion',
  };

  /// Catálogo. El servicio ya lo devuelve filtrado a lo que el usuario puede
  /// ver, según su grupo y el nivel de acceso de cada video.
  Future<List<Map<String, dynamic>>> videos({String orden = 'reciente'}) async =>
      comoLista(await _api.get('/$_s/videos',
          query: {'orden': _orden[orden] ?? 'fecha'}));

  Future<Map<String, dynamic>> video(String id) async =>
      comoMapa(await _api.get('/$_s/videos/$id'));

  /// URL del manifiesto HLS, o null si el video sigue en proceso.
  ///
  /// Los segmentos van referenciados de forma relativa dentro del manifiesto,
  /// así que resuelven contra esta misma URL y siguen entrando por el bus. El
  /// servicio de Streaming les añade el token al servir la lista, porque el
  /// reproductor pide cada segmento sin encabezados.
  Future<String?> manifiesto(String id) async {
    final v = await video(id);
    if (!comoBool(v['hlsListo'])) return null;
    return _api.urlConToken('/$_s/videos/$id/index.m3u8');
  }
}
