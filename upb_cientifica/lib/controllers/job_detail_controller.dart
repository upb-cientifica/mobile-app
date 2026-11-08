import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api.dart';
import 'async_state.dart';

/// Detalle de un trabajo del clúster.
///
/// Mientras el trabajo corre, la salida se relee cada pocos segundos: el
/// planificador va escribiendo el stdout del proceso y el progreso sale de las
/// líneas `PROGRESO: n` que el propio programa emite.
class JobDetailController extends ChangeNotifier with AsyncState {
  JobDetailController(this._api, this.jobId) {
    load();
  }

  final Api _api;
  final String jobId;

  static const List<String> tabs = ['Registro', 'Salida', 'Errores', 'Resultados', 'Métricas'];
  String _tab = tabs.first;
  String get tab => _tab;

  Map<String, dynamic> job = const {};
  List<Map<String, dynamic>> eventos = const [];
  List<String> salida = const [];
  List<String> errores = const [];
  List<Map<String, dynamic>> resultados = const [];
  List<Map<String, dynamic>> metricas = const [];

  Timer? _sondeo;

  bool get enCurso => job['estado'] == 'ejecutando' || job['estado'] == 'cola';

  /// Tiempo transcurrido, legible.
  String get duracionTexto => _duracion((job['duracionSeg'] as num?)?.toInt() ?? 0);

  Future<void> load() => run(() async {
        job = await _api.hpc.detalle(jobId);
        salida = (job['salidaEstandar'] as List? ?? []).map((e) => '$e').toList();
        errores = (job['errores'] as List? ?? []).map((e) => '$e').toList();
        eventos = _eventos();
        metricas = _metricas();
        resultados = await _resultados();
        _programarSondeo();
      });

  /// Relectura ligera mientras el trabajo avanza: sólo estado y salida.
  Future<void> _refrescar() async {
    try {
      job = await _api.hpc.detalle(jobId);
      salida = (job['salidaEstandar'] as List? ?? []).map((e) => '$e').toList();
      errores = (job['errores'] as List? ?? []).map((e) => '$e').toList();
      eventos = _eventos();
      metricas = _metricas();
      notifyListeners();
      _programarSondeo();
    } catch (_) {/* se reintenta en el próximo ciclo */}
  }

  void _programarSondeo() {
    _sondeo?.cancel();
    if (!enCurso) return;
    _sondeo = Timer(const Duration(seconds: 3), _refrescar);
  }

  /// Línea de tiempo del trabajo a partir de lo que el planificador reporta.
  /// No se inventan marcas de tiempo: sólo se nombra lo que consta.
  List<Map<String, dynamic>> _eventos() {
    final estado = '${job['estado']}';
    final salidaCodigo = job['codigoSalida'];
    return [
      {'tipo': 'Encolado', 'mensaje': '${job['creadoEn'] ?? ''}'},
      if (estado != 'cola')
        {'tipo': 'Ejecutando', 'mensaje': '${job['procesos']} procesos · ${job['comando']}'},
      if (estado == 'completado')
        {'tipo': 'Completado', 'mensaje': 'código de salida $salidaCodigo'},
      if (estado == 'fallido')
        {'tipo': 'Fallido', 'mensaje': '${job['mensaje']}'},
      if (estado == 'cancelado')
        {'tipo': 'Cancelado', 'mensaje': 'cancelado por el usuario'},
    ];
  }

  /// Métricas del trabajo. Son las que el planificador realmente conoce: no hay
  /// instrumentación por proceso, así que no se muestran eficiencias inventadas.
  List<Map<String, dynamic>> _metricas() {
    final progreso = (job['progreso'] as num?)?.toInt() ?? 0;
    final duracion = (job['duracionSeg'] as num?)?.toInt() ?? 0;
    final codigo = (job['codigoSalida'] as num?)?.toInt() ?? -1;
    return [
      {'label': 'Progreso', 'valor': '$progreso%', 'fraccion': progreso / 100},
      {'label': 'Procesos MPI', 'valor': '${job['procesos']}', 'fraccion': null},
      {'label': 'Duración', 'valor': _duracion(duracion), 'fraccion': null},
      if (codigo >= 0)
        {'label': 'Código de salida', 'valor': '$codigo', 'fraccion': null},
    ];
  }

  /// Los resultados son los archivos que el trabajo dejó en el Home. Se leen del
  /// Shared File Server, que es donde quedaron de verdad.
  Future<List<Map<String, dynamic>>> _resultados() async {
    final ruta = '${job['rutaHome'] ?? ''}';
    if (ruta.isEmpty) return const [];
    try {
      final c = await _api.archivos.listar(ruta);
      return c.archivos;
    } catch (_) {
      return const [];
    }
  }

  void setTab(String tab) {
    _tab = tab;
    notifyListeners();
  }

  Future<void> cancel() async {
    await _api.hpc.cancelar(jobId);
    await load();
  }

  /// Reejecutar encola un trabajo nuevo con el mismo comando: el planificador
  /// no reenvía uno terminado.
  Future<String> rerun() => _api.hpc.reejecutar(jobId);

  static String _duracion(int seg) {
    if (seg <= 0) return '—';
    if (seg < 60) return '$seg s';
    if (seg < 3600) return '${seg ~/ 60} min';
    return '${(seg / 3600).toStringAsFixed(1)} h';
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    super.dispose();
  }
}
