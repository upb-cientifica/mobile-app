import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';
import 'hpc.dart';

/// Monitoreo del sistema: disponibilidad de los servicios, métricas de máquina
/// y reglas de alerta.
///
/// El resumen mezcla dos servicios que hablan protocolos distintos —las
/// métricas salen del Monitoreo por REST y los trabajos activos del clúster por
/// Java RMI— y la vista no distingue: para ella todo llega igual del bus.
class ServicioMonitoreo {
  ServicioMonitoreo(this._api, this._hpc);

  final ApiClient _api;
  final ServicioHpc _hpc;

  static const String _s = Servicios.monitoreo;

  /// El Monitoreo guarda histórico de **disponibilidad**, no de CPU y memoria.
  /// La serie de las gráficas en vivo se acumula aquí, con cada lectura.
  final List<_Punto> _serie = [];
  static const int _maxSerie = 30;

  /// Resumen completo para la pantalla de monitoreo.
  Future<Map<String, dynamic>> resumen() async {
    // Las cuatro fuentes salen a la vez y cada una cae por su cuenta: que el
    // clúster esté caído no debe dejar la pantalla sin las métricas de máquina,
    // ni al revés. La pantalla de monitoreo es justamente donde hay que poder
    // ver que algo no responde.
    final fHost = _seguro(() async => comoMapa(await _api.get('/$_s/host')),
        const <String, dynamic>{});
    final fServicios = _seguro(() async => comoLista(await _api.get('/$_s/servicios')),
        const <Map<String, dynamic>>[]);
    final fNodos = _seguro(_hpc.nodos, const <Map<String, dynamic>>[]);
    final fTrabajos = _seguro(_hpc.listar, const Trabajos(trabajos: [], conteo: {}));

    final host = await fHost;
    final servicios = await fServicios;
    final nodos = await fNodos;
    final trabajos = await fTrabajos;

    final cpu = comoDecimal(host['cpuPct']).round();
    final mem = comoDecimal(host['memoriaPct']).round();
    final disco = comoDecimal(host['discoPct']).round();

    _serie.add(_Punto(cpu, mem, trabajos.conteo['ejecutando'] ?? 0));
    while (_serie.length > _maxSerie) {
      _serie.removeAt(0);
    }

    return {
      'recursos': {
        'cpuPct': cpu,
        'memoriaPct': mem,
        'almacenamientoPct': disco,
        'carga': comoDecimal(host['carga']),
        'procesadores': comoEntero(host['procesadores']),
      },
      'nodos': {
        'disponibles': nodos.where((n) => comoBool(n['disponible'])).length,
        'total': nodos.length,
      },
      'trabajos': {
        'ejecutando': trabajos.conteo['ejecutando'] ?? 0,
        'cola': trabajos.conteo['cola'] ?? 0,
      },
      'graficas': {
        'cpu': [for (final p in _serie) {'valor': p.cpu}],
        'memoria': [for (final p in _serie) {'valor': p.mem}],
        // Sin histórico de disco: se dibuja la carga de trabajos, que es lo que
        // el Monitoreo y el clúster sí saben de verdad.
        'cargaTrabajos': [for (final p in _serie) {'valor': p.trabajos}],
        'tiempoEjecucionProm': [for (final p in _serie) {'valor': p.trabajos}],
      },
      'servicios': servicios.map(_aServicio).toList(),
    };
  }

  /// Estado de cada servicio vigilado, para la pantalla de administración.
  Future<List<Map<String, dynamic>>> servicios() async =>
      comoLista(await _api.get('/$_s/servicios')).map(_aServicio).toList();

  /// Alertas disparadas, de más reciente a más antigua.
  Future<List<Map<String, dynamic>>> alertas({String? categoria}) async {
    final d = comoMapa(await _api.get('/$_s/alertas'));
    final eventos = comoLista(d['eventos'])
        .where((e) => comoBool(e['disparada']))
        .map(_aAlerta)
        .where((a) => categoria == null || a['categoria'] == categoria)
        .toList();
    eventos.sort((a, b) => '${b['creadaEn']}'.compareTo('${a['creadaEn']}'));
    return eventos;
  }

  /// Reglas configuradas (umbral por métrica).
  Future<List<Map<String, dynamic>>> reglas() async {
    final d = comoMapa(await _api.get('/$_s/alertas'));
    return comoLista(d['reglas']);
  }

  /// Disponibilidad y latencia media por servicio en los últimos [dias].
  Future<List<Map<String, dynamic>>> reporte({int dias = 7}) async {
    final d = comoMapa(await _api.get('/$_s/reportes', query: {'dias': dias}));
    return comoLista(d['servicios']);
  }

  Map<String, dynamic> _aServicio(Map<String, dynamic> s) {
    final estado = '${s['estado']}';
    return {
      'nombre': s['nombre'] ?? '',
      'codigo': s['nombre'] ?? '',
      'estado': switch (estado) {
        'disponible' => 'operativo',
        'caido' => 'caido',
        _ => 'mantenimiento',
      },
      'tiempoRespuestaMs': comoEntero(s['latenciaMs'], -1),
      'ultimaVerificacion': s['ultimaLectura'],
    };
  }

  /// Evento de alerta del Monitoreo → la forma que consume `AlertItem`.
  ///
  /// El Monitoreo no guarda "leída": eso es de cada persona en cada dispositivo
  /// y ningún servicio del sistema es su dueño. Lo resuelve la app.
  Map<String, dynamic> _aAlerta(Map<String, dynamic> e) {
    final metrica = '${e['metrica']}';
    final servicio = '${e['servicio'] ?? ''}';
    final instante = comoEntero(e['instante']);
    return {
      'id': '${e['reglaId']}-${e['instante']}',
      'categoria': servicio.isEmpty ? 'sistema' : _categoria(servicio),
      'severidad': '${e['severidad']}',
      'titulo': servicio.isEmpty
          ? '$metrica por encima del umbral'
          : '$servicio: $metrica en ${comoDecimal(e['valor']).round()}',
      'mensaje': 'Umbral ${comoDecimal(e['umbral']).round()} · '
          'valor ${comoDecimal(e['valor']).round()}',
      'creadaEn': instante > 0
          ? DateTime.fromMillisecondsSinceEpoch(instante).toIso8601String()
          : null,
    };
  }

  /// Agrupa la alerta por el servicio que la originó, para el filtro por
  /// categoría de la pantalla de alertas.
  static String _categoria(String servicio) {
    final s = servicio.toLowerCase();
    if (s.contains('hpc') || s.contains('cluster')) return 'hpc';
    if (s.contains('sync')) return 'sync';
    if (s.contains('file') || s.contains('shared')) return 'archivos';
    if (s.contains('usuario')) return 'seguridad';
    return 'sistema';
  }
}

class _Punto {
  const _Punto(this.cpu, this.mem, this.trabajos);

  final int cpu;
  final int mem;
  final int trabajos;
}

/// Ejecuta [f] y devuelve [porDefecto] si falla. Se usa sólo donde la caída de
/// una fuente no invalida el resto de la pantalla.
Future<T> _seguro<T>(Future<T> Function() f, T porDefecto) async {
  try {
    return await f();
  } catch (_) {
    return porDefecto;
  }
}
