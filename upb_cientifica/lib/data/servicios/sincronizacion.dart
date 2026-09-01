import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Sincronización de archivos entre los dispositivos del usuario.
///
/// El servicio habla **gRPC** con su cliente de escritorio —que es lo que
/// necesita para transferir por bloques y reanudar— y además publica una cara
/// REST de consulta. Es esa la que media el bus: mediar gRPC a REST
/// desvirtuaría el protocolo, así que el bus lo publica en su registro como
/// «no mediado» y el cliente nativo conecta directo.
///
/// Consecuencia para la app: desde el móvil se **observa** la sincronización y
/// se **resuelven conflictos**, que es todo lo que la cara REST permite hacer.
/// Empujar bloques exigiría un cliente gRPC dentro de Flutter.
class ServicioSincronizacion {
  ServicioSincronizacion(this._api);

  final ApiClient _api;

  static const String _s = Servicios.sync;

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
      'estadoGeneral': pendientes > 0 ? 'conflicto' : '${e['estadoGeneral'] ?? 'sincronizado'}',
      'pendientesTotal': pendientes,
      'archivos': comoEntero(e['archivos']),
      'bytes': comoEntero(e['bytes']),
      'ultimaSync': e['ultimaSync'],
      'dispositivos': dispositivos.map((d) => {
            'id': '${d['id']}',
            'nombre': d['nombre'] ?? '',
            'plataforma': d['plataforma'] ?? '',
            'carpetaLocal': d['carpetaLocal'] ?? '',
            'ultimaSync': d['ultimaSync'],
            'estado': '${d['estado']}',
            // Los conflictos son del archivo, no del dispositivo, pero se
            // atribuyen al que los provocó: es lo que hay que ir a mirar.
            'pendientes': conflictos.where((c) => '${c['dispositivo']}' == '${d['id']}').length,
          }).toList(),
      'conflictos': conflictos,
    };
  }

  Future<List<Map<String, dynamic>>> dispositivos() async =>
      comoLista(await _api.get('/$_s/dispositivos'));

  Future<List<Map<String, dynamic>>> conflictos() async =>
      comoLista(await _api.get('/$_s/conflictos'));

  /// Versiones guardadas de un archivo. La ruta va como parámetro y no dentro
  /// del camino: el servidor decodifica `%2F` a `/` y rompería el enrutado.
  Future<List<Map<String, dynamic>>> versiones(String ruta) async =>
      comoLista(await _api.get('/$_s/versiones', query: {'ruta': ruta}));

  Future<List<Map<String, dynamic>>> archivos() async =>
      comoLista(await _api.get('/$_s/archivos'));

  Future<List<Map<String, dynamic>>> actividad() async =>
      comoLista(await _api.get('/$_s/actividad'));

  /// Resuelve un conflicto. Es la única escritura que la cara REST expone, y
  /// la que hace útil llevar la sincronización en el bolsillo: el conflicto se
  /// decide donde esté la persona, no donde esté su portátil.
  Future<void> resolver(String conflictoId, String estrategia) =>
      _api.post('/$_s/conflictos/resolver', query: {
        'id': conflictoId,
        'estrategia': estrategias[estrategia] ?? 'MANTENER_SERVIDOR',
      });
}
