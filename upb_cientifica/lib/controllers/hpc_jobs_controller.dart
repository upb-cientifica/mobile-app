import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/hpc_job.dart';
import 'async_state.dart';

/// Cola de trabajos del clúster.
///
/// Detrás de cada lectura hay una invocación sobre un objeto Java RMI que el
/// bus hace por cuenta de la app.
class HpcJobsController extends ChangeNotifier with AsyncState {
  HpcJobsController(this._api) {
    load();
  }

  final Api _api;

  String _filter = 'Todos';
  String get filter => _filter;

  List<HpcJob> jobs = const [];
  int enCola = 0, ejecutando = 0, completados = 0, fallidos = 0;

  List<HpcJob> get filteredJobs => jobs;

  Future<void> load() => run(() async {
        final t = await _api.hpc.listar(filtro: hpcFilterToApi(_filter));
        jobs = t.trabajos.map(HpcJob.fromApi).toList();
        enCola = t.conteo['cola'] ?? 0;
        ejecutando = t.conteo['ejecutando'] ?? 0;
        completados = t.conteo['completados'] ?? 0;
        fallidos = t.conteo['fallidos'] ?? 0;
      });

  void setFilter(String filter) {
    _filter = filter;
    load();
  }
}
