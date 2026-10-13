import 'dart:io';

import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Sincroniza archivos y resuelve conflictos mediante REST a través del bus.
class ServicioSincronizacion {
  ServicioSincronizacion(this._api);

  final ApiClient _api;

  static const String _s = Servicios.sync;

  Future<void> comprobarRed() async {
    await _api.get('/$_s/estado').timeout(const Duration(seconds: 5));
  }

  Future<String> registrar(String carpeta) async {
    final plataforma = Platform.isIOS ? 'ios' : 'android';
    final data = comoMapa(
      await _api.post(
        '/$_s/dispositivos',
        query: {
          'nombre': 'Móvil UPB ($plataforma)',
          'plataforma': plataforma,
          'carpeta': carpeta,
        },
      ),
    );
    final id = data['dispositivoId']?.toString() ?? '';
    if (id.isEmpty) throw StateError('El servidor no devolvió dispositivoId');
    return id;
  }

  Future<List<Map<String, dynamic>>> manifiesto() async =>
      comoLista(await _api.get('/$_s/manifiesto'));

  Future<void> descargar(String ruta, File destino, int version) =>
      _api.getFile(
        '/$_s/contenido',
        destino,
        query: {'ruta': ruta, 'version': version},
      );

  Future<Map<String, dynamic>> subir(
    String ruta,
    File archivo,
    int base,
    String hash,
    String dispositivo,
  ) async => comoMapa(
    await _api.postFile(
      '/$_s/contenido',
      archivo,
      query: {
        'ruta': ruta,
        'base': base,
        'hash': hash,
        'dispositivo': dispositivo,
      },
    ),
  );

  Future<Map<String, dynamic>> eliminar(
    String ruta,
    int base,
    String dispositivo,
  ) async => comoMapa(
    await _api.post(
      '/$_s/contenido/eliminar',
      query: {'ruta': ruta, 'base': base, 'dispositivo': dispositivo},
    ),
  );

  /// Estrategias de resolución tal como las nombra el servicio.
  static const Map<String, String> estrategias = {
    'local': 'MANTENER_CLIENTE',
    'servidor': 'MANTENER_SERVIDOR',
    'ambos': 'MANTENER_AMBOS',
  };

  /// Estado completo, en la forma que consume `SyncState`.
  ///
  /// El servicio devuelve el número de dispositivos en `/estado` y la lista en
  /// `/dispositivos`: se piden las dos y se arma una sola vista.
  Future<Map<String, dynamic>> estado() async {
    final fEstado = _api.get('/$_s/estado').then(comoMapa);
    final fDisp = _api.get('/$_s/dispositivos').then(comoLista);
    final fConf = _api.get('/$_s/conflictos').then(comoLista);

    final e = await fEstado;
    final dispositivos = await fDisp;
    final conflictos = await fConf;

    final pendientes = comoEntero(e['conflictosPendientes']);
    return {
      // El servicio dice "conflictos" en plural; la interfaz nombra el estado
      // en singular.
      'estadoGeneral': pendientes > 0
          ? 'conflicto'
          : '${e['estadoGeneral'] ?? 'sincronizado'}',
      'pendientesTotal': pendientes,
      'archivos': comoEntero(e['archivos']),
      'bytes': comoEntero(e['bytes']),
      'ultimaSync': e['ultimaSync'],
      'dispositivos': dispositivos
          .map(
            (d) => {
              'id': '${d['id']}',
              'nombre': d['nombre'] ?? '',
              'plataforma': d['plataforma'] ?? '',
              'carpetaLocal': d['carpetaLocal'] ?? '',
              'ultimaSync': d['ultimaSync'],
              'estado': '${d['estado']}',
              // Los conflictos son del archivo, no del dispositivo, pero se
              // atribuyen al que los provocó: es lo que hay que ir a mirar.
              'pendientes': conflictos
                  .where((c) => '${c['dispositivo']}' == '${d['id']}')
                  .length,
            },
          )
          .toList(),
      'conflictos': conflictos,
    };
  }

  Future<List<Map<String, dynamic>>> dispositivos() async =>
      comoLista(await _api.get('/$_s/dispositivos'));

  Future<List<Map<String, dynamic>>> conflictos() async =>
      comoLista(await _api.get('/$_s/conflictos', query: {'resueltos': true}));

  /// Versiones guardadas de un archivo. La ruta va como parámetro y no dentro
  /// del camino: el servidor decodifica `%2F` a `/` y rompería el enrutado.
  Future<List<Map<String, dynamic>>> versiones(String ruta) async =>
      comoLista(await _api.get('/$_s/versiones', query: {'ruta': ruta}));

  Future<List<Map<String, dynamic>>> archivos() async =>
      comoLista(await _api.get('/$_s/archivos'));

  Future<List<Map<String, dynamic>>> actividad() async =>
      comoLista(await _api.get('/$_s/actividad'));

  /// Resuelve un conflicto con la estrategia elegida.
  Future<void> resolver(String conflictoId, String estrategia) => _api.post(
    '/$_s/conflictos/resolver',
    query: {
      'id': conflictoId,
      'estrategia': estrategias[estrategia] ?? 'MANTENER_SERVIDOR',
    },
  );
}
