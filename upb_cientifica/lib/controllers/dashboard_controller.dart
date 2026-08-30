import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/activity_item.dart';
import 'async_state.dart';

class DashboardController extends ChangeNotifier with AsyncState {
  DashboardController(this._api) {
    load();
  }

  final ApiClient _api;

  String saludo = 'Hola';
  int usadoBytes = 0;
  int cuotaBytes = 1;
  int porcentaje = 0;
  int archivos = 0;
  String almacenamientoTexto = '';
  String syncEstado = 'sincronizado';
  int syncPendientes = 0;
  bool enRedLocal = false;
  int hpcEjecutando = 0;
  int hpcCola = 0;
  List<ActivityItem> actividad = const [];

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/dashboard') as Map);
        final a = Map<String, dynamic>.from(j['almacenamiento'] as Map);
        final s = Map<String, dynamic>.from(j['sincronizacion'] as Map);
        final r = Map<String, dynamic>.from(j['red'] as Map);
        final h = Map<String, dynamic>.from(j['trabajosHpc'] as Map);

        saludo = j['saludo'] as String? ?? 'Hola';
        usadoBytes = (a['usadoBytes'] as num?)?.toInt() ?? 0;
        cuotaBytes = (a['cuotaBytes'] as num?)?.toInt() ?? 1;
        porcentaje = (a['porcentaje'] as num?)?.toInt() ?? 0;
        archivos = (a['archivos'] as num?)?.toInt() ?? 0;
        almacenamientoTexto = a['texto'] as String? ?? '';
        syncEstado = s['estado'] as String? ?? 'sincronizado';
        syncPendientes = (s['pendientes'] as num?)?.toInt() ?? 0;
        enRedLocal = r['enRedLocalUpb'] == true;
        hpcEjecutando = (h['ejecutando'] as num?)?.toInt() ?? 0;
        hpcCola = (h['cola'] as num?)?.toInt() ?? 0;
        actividad = (j['actividadReciente'] as List? ?? [])
            .map((e) => ActivityItem.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
}
