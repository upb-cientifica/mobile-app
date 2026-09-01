import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Clúster de cómputo (trabajos MPI).
///
/// Al otro lado hay un **objeto remoto Java RMI**, no un servicio REST. El bus
/// recibe la llamada REST, busca el stub en el registro RMI e invoca el método
/// correspondiente sobre `ClusterHpc`. Es la mediación que obliga a que el bus
/// corra sobre la JVM: RMI es un protocolo de Java y no hay cliente nativo
/// para Dart.
class ServicioHpc {
  ServicioHpc(this._api);

  final ApiClient _api;

  static const String _s = Servicios.hpc;

  /// Estados del planificador → vocabulario de la interfaz.
  static const Map<String, String> _estados = {
    'ENCOLADO': 'cola',
    'EJECUTANDO': 'ejecutando',
    'COMPLETADO': 'completado',
    'FALLIDO': 'fallido',
    'CANCELADO': 'cancelado',
  };

  /// Trabajos visibles para el usuario, con el conteo por estado.
  ///
  /// El clúster devuelve la cola completa y el filtrado es de la vista: son
  /// pocos trabajos y así el conteo de las pestañas siempre cuadra con el total.
  Future<Trabajos> listar({String filtro = 'todos'}) async {
    final crudos = comoLista(await _api.get('/$_s/trabajos')).map(_aTrabajo).toList();

    int cuenta(String e) => crudos.where((t) => t['estado'] == e).length;
    final conteo = {
      'cola': cuenta('cola'),
      'ejecutando': cuenta('ejecutando'),
      'completados': cuenta('completado'),
      'fallidos': cuenta('fallido') + cuenta('cancelado'),
    };

    final visibles = switch (filtro) {
      'cola' => crudos.where((t) => t['estado'] == 'cola'),
      'ejecutando' => crudos.where((t) => t['estado'] == 'ejecutando'),
      'completados' => crudos.where((t) => t['estado'] == 'completado'),
      'fallidos' => crudos.where((t) => t['estado'] == 'fallido' || t['estado'] == 'cancelado'),
      _ => crudos,
    };

    return Trabajos(trabajos: visibles.toList(), conteo: conteo);
  }

  /// Detalle de un trabajo junto con su salida estándar.
  Future<Map<String, dynamic>> detalle(String id) async {
    final t = _aTrabajo(comoMapa(await _api.get('/$_s/trabajos/$id')));
    final lineas = await salida(id);
    return {
      ...t,
      'salidaEstandar': lineas,
      // El planificador separa el código de salida del texto: un trabajo que
      // terminó mal deja el motivo en `mensaje`.
      'errores': t['estado'] == 'fallido' && '${t['mensaje']}'.isNotEmpty
          ? ['${t['mensaje']}']
          : const <String>[],
    };
  }

  /// Salida estándar acumulada, línea a línea.
  Future<List<String>> salida(String id) async {
    try {
      final d = comoMapa(await _api.get('/$_s/trabajos/$id/salida'));
      return '${d['salida'] ?? ''}'.split('\n').where((l) => l.isNotEmpty).toList();
    } catch (_) {
      // Un trabajo recién encolado todavía no tiene archivo de salida.
      return const [];
    }
  }

  /// Encola un trabajo. El clúster recibe un ejecutable con sus argumentos, tal
  /// como espera `mpirun`, y la ruta del Home de donde traer código y datos.
  Future<String> enviar({
    required String nombre,
    required String comando,
    int procesos = 1,
    String rutaHome = '',
  }) async {
    final d = comoMapa(await _api.post('/$_s/trabajos', query: {
      'nombre': nombre,
      'comando': comando,
      'procesos': procesos,
      'rutaHome': rutaHome,
    }));
    return '${d['id'] ?? ''}';
  }

  Future<bool> cancelar(String id) async {
    final d = comoMapa(await _api.delete('/$_s/trabajos/$id'));
    return comoBool(d['cancelado']);
  }

  /// Reejecuta un trabajo: el clúster no reenvía por sí mismo, así que se
  /// encola uno nuevo con el mismo comando.
  Future<String> reejecutar(String id) async {
    final t = comoMapa(await _api.get('/$_s/trabajos/$id'));
    return enviar(
      nombre: '${t['nombre']}',
      comando: '${t['comando'] ?? ''}',
      procesos: comoEntero(t['procesos'], 1),
      rutaHome: '${t['rutaHome'] ?? ''}',
    );
  }

  /// Nodos del clúster y sus ranuras de ejecución.
  Future<List<Map<String, dynamic>>> nodos() async =>
      comoLista(await _api.get('/$_s/nodos'));

  Future<int> slotsDisponibles() async {
    final d = comoMapa(await _api.get('/$_s/slots'));
    return comoEntero(d['slotsDisponibles']);
  }

  /// `TrabajoInfo` del objeto remoto → el mapa que consume `HpcJob`.
  Map<String, dynamic> _aTrabajo(Map<String, dynamic> t) {
    final comando = '${t['comando'] ?? ''}';
    return {
      'id': '${t['id'] ?? ''}',
      'nombre': t['nombre'] ?? '',
      'estado': _estados['${t['estado']}'] ?? 'cola',
      'procesos': comoEntero(t['procesos']),
      'progreso': comoEntero(t['progreso']),
      'propietario': t['propietario'] ?? '',
      'creadoEn': t['creadoEn'],
      'duracionSeg': comoEntero(t['duracionSeg']),
      'codigoSalida': comoEntero(t['codigoSalida'], -1),
      'mensaje': t['mensaje'] ?? '',
      'comando': comando,
      // Lo que identifica la carga es el ejecutable, no un lenguaje declarado:
      // el clúster recibe un comando, no un tipo de proyecto.
      'programa': _programa(comando),
      'rutaHome': t['rutaHome'] ?? '',
    };
  }

  /// Nombre corto del ejecutable dentro del comando completo.
  static String _programa(String comando) {
    final primera = comando.trim().split(RegExp(r'\s+')).first;
    if (primera.isEmpty) return '—';
    final barra = primera.lastIndexOf('/');
    return barra < 0 ? primera : primera.substring(barra + 1);
  }
}

/// Cola de trabajos con su resumen por estado.
class Trabajos {
  const Trabajos({required this.trabajos, required this.conteo});

  final List<Map<String, dynamic>> trabajos;
  final Map<String, int> conteo;
}
