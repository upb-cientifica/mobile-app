import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Álbum de fotos del Home: colecciones, etiquetas e imágenes.
///
/// El servicio guarda las imágenes por contenido (direccionadas por sha256) y
/// genera las miniaturas; la app sólo pide URLs y las dibuja.
class ServicioFotos {
  ServicioFotos(this._api);

  final ApiClient _api;

  static const String _s = Servicios.fotos;

  /// Etiqueta que hace las veces de "favorito".
  ///
  /// El servicio no tiene un campo de favoritos: tiene etiquetas, que son su
  /// forma propia de clasificar. Marcar una foto es etiquetarla, y así el
  /// favorito sobrevive fuera de la app y lo ve también la web.
  static const String etiquetaFavorito = 'favorito';

  Future<List<Map<String, dynamic>>> albumes() async =>
      comoLista(await _api.get('/$_s/albums')).map((a) => {
            'id': '${a['id']}',
            'nombre': a['titulo'] ?? '',
            'proyecto': a['proyecto'] ?? '',
            'fotos': comoEntero(a['numImagenes']),
            'rol': a['miRol'] ?? '',
          }).toList();

  /// Imágenes, opcionalmente de un álbum o filtradas por etiqueta.
  Future<List<Map<String, dynamic>>> fotos({String? albumId, String? etiqueta}) async {
    final crudas = (albumId != null && albumId.isNotEmpty && albumId != 'all')
        ? comoLista(await _api.get('/$_s/albums/$albumId/imagenes'))
        : comoLista(await _api.get('/$_s/buscar',
            query: {if (etiqueta != null && etiqueta.isNotEmpty) 'etiqueta': etiqueta}));

    // El token va en la URL: los widgets de imagen descargan por su cuenta y no
    // siempre arrastran los encabezados. El bus y el servicio aceptan `?token=`.
    // Se lee una sola vez para todo el lote, no una por foto.
    final token = await _api.accessToken;
    return crudas.map((im) => _aFoto(im, token)).toList();
  }

  /// Sólo las marcadas como favoritas.
  Future<List<Map<String, dynamic>>> favoritas() => fotos(etiqueta: etiquetaFavorito);

  /// Etiquetas en uso. El servicio no publica un catálogo: se deduce de las
  /// fotos, que es exactamente lo que hay.
  Future<List<String>> etiquetas() async {
    final fs = comoLista(await _api.get('/$_s/buscar'));
    final todas = <String>{};
    for (final f in fs) {
      todas.addAll(comoTextos(f['etiquetas']));
    }
    final lista = todas.toList()..sort();
    return lista;
  }

  Map<String, dynamic> _aFoto(Map<String, dynamic> im, String? token) {
    final id = '${im['id']}';
    final etiquetas = comoTextos(im['etiquetas']);
    return {
      'id': id,
      'titulo': im['titulo'] ?? '(sin título)',
      'albumId': '${im['albumId'] ?? ''}',
      'etiquetas': etiquetas,
      'favorito': etiquetas.contains(etiquetaFavorito),
      'subidaEn': im['subidaEn'],
      'ancho': comoEntero(im['ancho']),
      'alto': comoEntero(im['alto']),
      'descripcion': im['descripcion'] ?? '',
      'url': _api.urlCon('/$_s/imagenes/$id', token),
      'miniatura': _api.urlCon('/$_s/imagenes/$id/miniatura', token),
    };
  }
}
