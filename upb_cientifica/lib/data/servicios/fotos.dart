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

  Map<String, dynamic> _aAlbum(Map<String, dynamic> a) => {
    'id': '${a['id']}',
    'nombre': a['titulo'] ?? '',
    'proyecto': a['proyecto'] ?? '',
    'fotos': comoEntero(a['numImagenes']),
    'rol': a['miRol'] ?? '',
    'publico': comoBool(a['publico']),
    'urlPublica': a['urlPublica'],
    'compartidoCon': comoTextos(a['compartidoCon']),
  };

  Future<List<Map<String, dynamic>>> albumes() async =>
      comoLista(await _api.get('/$_s/albums')).map(_aAlbum).toList();

  Future<Map<String, dynamic>> compartir(
    String albumId,
    String correo, {
    required bool conceder,
  }) async => _aAlbum(
    comoMapa(
      await _api.post(
        '/$_s/albums/$albumId/compartir',
        query: {
          'correo': normalizarCorreo(correo),
          'accion': conceder ? 'grant' : 'revoke',
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> publicar(
    String albumId, {
    required bool activo,
  }) async => _aAlbum(
    comoMapa(
      await _api.post(
        '/$_s/albums/$albumId/publico',
        query: {'accion': activo ? 'activar' : 'desactivar'},
      ),
    ),
  );

  Future<Map<String, dynamic>> actualizar(
    String id, {
    required String titulo,
    required String descripcion,
    required List<String> etiquetas,
  }) async {
    final imagen = comoMapa(
      await _api.patch(
        '/$_s/imagenes/$id',
        query: {
          'titulo': titulo,
          'descripcion': descripcion,
          'etiquetas': analizarEtiquetas(etiquetas.join(',')).join(','),
        },
      ),
    );
    return _aFoto(imagen, await _api.accessToken);
  }

  /// Dentro de un álbum, el servicio no filtra: se aplica el mismo criterio aquí.
  Future<List<Map<String, dynamic>>> fotos({
    String? albumId,
    String? etiqueta,
    String q = '',
  }) async {
    final enAlbum = albumId != null && albumId.isNotEmpty && albumId != 'all';
    var crudas = enAlbum
        ? comoLista(await _api.get('/$_s/albums/$albumId/imagenes'))
        : comoLista(
            await _api.get(
              '/$_s/buscar',
              query: {
                'q': q,
                if (etiqueta != null && etiqueta.isNotEmpty)
                  'etiqueta': etiqueta,
              },
            ),
          );
    if (enAlbum) {
      final busqueda = q.trim().toLowerCase();
      crudas = crudas.where((im) {
        final etiquetas = comoTextos(im['etiquetas']);
        return (etiqueta == null ||
                etiqueta.isEmpty ||
                etiquetas.contains(etiqueta)) &&
            [
              im['titulo'] ?? '',
              im['descripcion'] ?? '',
              ...etiquetas,
            ].any((valor) => '$valor'.toLowerCase().contains(busqueda));
      }).toList();
    }

    // El token va en la URL: los widgets de imagen descargan por su cuenta y no
    // siempre arrastran los encabezados. El bus y el servicio aceptan `?token=`.
    // Se lee una sola vez para todo el lote, no una por foto.
    final token = await _api.accessToken;
    return crudas.map((im) => _aFoto(im, token)).toList();
  }

  /// Sólo las marcadas como favoritas.
  Future<List<Map<String, dynamic>>> favoritas() =>
      fotos(etiqueta: etiquetaFavorito);

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
      'albumId': '${im['albumId'] ?? comoMapa(im['album'])['id'] ?? ''}',
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

/// Completa usuarios institucionales sin alterar dominios explícitos.
String normalizarCorreo(String texto) {
  final correo = texto.trim().toLowerCase();
  return correo.isEmpty || correo.contains('@') ? correo : '$correo@upb.edu.co';
}

bool correoInstitucionalValido(String texto) => RegExp(
  r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@upb\.edu\.co$",
).hasMatch(normalizarCorreo(texto));

/// Las comas separan etiquetas; se conserva el orden de primera aparición.
List<String> analizarEtiquetas(String texto) => texto
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .where((e) => e.isNotEmpty)
    .toSet()
    .toList();
