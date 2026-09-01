import 'archivos.dart';
import 'conversion.dart';
import 'hpc.dart';
import 'sincronizacion.dart';

/// El panel de inicio.
///
/// Es la única pantalla que no corresponde a un servicio: resume cuatro. Aquí
/// está la agregación que antes vivía en un backend intermedio y que ahora hace
/// la app, entrando por el bus como cualquier otro consumidor.
///
/// Las cuatro lecturas salen a la vez y cada una cae por su cuenta: un servicio
/// caído deja su tarjeta vacía, no la pantalla entera.
class ServicioPanel {
  ServicioPanel(this._archivos, this._sync, this._hpc);

  final ServicioArchivos _archivos;
  final ServicioSincronizacion _sync;
  final ServicioHpc _hpc;

  Future<Map<String, dynamic>> resumen({String nombre = ''}) async {
    final fHome = _seguro(_archivos.home, const <String, dynamic>{});
    final fSync = _seguro(_sync.estado, const <String, dynamic>{});
    final fTrabajos = _seguro(_hpc.listar, const Trabajos(trabajos: [], conteo: {}));
    final fActividad = _seguro(_sync.actividad, const <Map<String, dynamic>>[]);

    final home = await fHome;
    final sync = await fSync;
    final trabajos = await fTrabajos;
    final actividad = await fActividad;

    final usado = comoEntero(home['usadoBytes']);
    final cuota = comoEntero(home['cuotaBytes'], 1);

    return {
      'saludo': saludo(nombre),
      'almacenamiento': {
        'usadoBytes': usado,
        'cuotaBytes': cuota,
        'porcentaje': comoEntero(home['porcentaje']),
        'archivos': comoEntero(home['archivos']),
        'texto': '${_legible(usado)} de ${_legible(cuota)}',
      },
      'sincronizacion': {
        'estado': sync['estadoGeneral'] ?? 'sincronizado',
        'pendientes': comoEntero(sync['pendientesTotal']),
      },
      'trabajosHpc': {
        'ejecutando': trabajos.conteo['ejecutando'] ?? 0,
        'cola': trabajos.conteo['cola'] ?? 0,
      },
      'actividadReciente': _actividad(actividad, trabajos.trabajos),
    };
  }

  /// Saludo por la hora del día. Es de la app, no de ningún servicio.
  static String saludo(String nombre) {
    final h = DateTime.now().hour;
    final momento = h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
    final primer = nombre.trim().split(RegExp(r'\s+')).first;
    return primer.isEmpty ? momento : '$momento, $primer';
  }

  /// Actividad reciente: lo que hicieron los dispositivos y lo que hizo el
  /// clúster, en una sola línea de tiempo.
  List<Map<String, dynamic>> _actividad(
      List<Map<String, dynamic>> sync, List<Map<String, dynamic>> trabajos) {
    final items = <Map<String, dynamic>>[
      for (final a in sync)
        {
          'tipo': 'sync',
          'titulo': '${a['accion']} · ${a['archivo']}',
          'detalle': '${a['dispositivo']}',
          'fecha': a['fecha'],
        },
      for (final t in trabajos.take(5))
        {
          'tipo': 'trabajo',
          'titulo': '${t['nombre']}',
          'detalle': 'Trabajo ${t['estado']} · ${t['procesos']} procesos',
          'fecha': t['creadoEn'],
        },
    ];
    items.sort((a, b) => '${b['fecha']}'.compareTo('${a['fecha']}'));
    return items.take(8).toList();
  }

  static String _legible(int bytes) {
    const u = ['B', 'KB', 'MB', 'GB', 'TB'];
    double n = bytes.toDouble();
    var i = 0;
    while (n >= 1024 && i < u.length - 1) {
      n /= 1024;
      i++;
    }
    return '${n < 10 ? n.toStringAsFixed(1) : n.round()} ${u[i]}';
  }
}

Future<T> _seguro<T>(Future<T> Function() f, T porDefecto) async {
  try {
    return await f();
  } catch (_) {
    return porDefecto;
  }
}
