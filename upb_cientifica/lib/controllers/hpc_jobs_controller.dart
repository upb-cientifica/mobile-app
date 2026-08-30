import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/hpc_job.dart';
import 'async_state.dart';

class HpcJobsController extends ChangeNotifier with AsyncState {
  HpcJobsController(this._api) {
    load();
  }

  final ApiClient _api;

  String _filter = 'Todos';
  String get filter => _filter;

  List<HpcJob> jobs = const [];
  int enCola = 0, ejecutando = 0, completados = 0, fallidos = 0;

  List<HpcJob> get filteredJobs => jobs;

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/hpc/trabajos',
            query: {'estado': hpcFilterToApi(_filter)}) as Map);
        jobs = (j['trabajos'] as List? ?? [])
            .map((e) => HpcJob.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
        final c = Map<String, dynamic>.from(j['conteo'] as Map? ?? {});
        enCola = (c['cola'] as num?)?.toInt() ?? 0;
        ejecutando = (c['ejecutando'] as num?)?.toInt() ?? 0;
        completados = (c['completados'] as num?)?.toInt() ?? 0;
        fallidos = (c['fallidos'] as num?)?.toInt() ?? 0;
      });

  void setFilter(String filter) {
    _filter = filter;
    load();
  }
}
