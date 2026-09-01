import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/activity_item.dart';
import 'async_state.dart';

/// Panel de inicio. Es la única pantalla que resume varios servicios a la vez:
/// el Home, la sincronización y el clúster. Esa agregación la hace
/// [Api.panel], que lanza las lecturas en paralelo por el bus.
class DashboardController extends ChangeNotifier with AsyncState {
  DashboardController(this._api, {this.nombreUsuario = ''}) {
    load();
  }

  final Api _api;
  final String nombreUsuario;

  String saludo = 'Hola';
  int usadoBytes = 0;
  int cuotaBytes = 1;
  int porcentaje = 0;
  int archivos = 0;
  String almacenamientoTexto = '';
  String syncEstado = 'sincronizado';
  int syncPendientes = 0;
  int hpcEjecutando = 0;
  int hpcCola = 0;
  List<ActivityItem> actividad = const [];

  Future<void> load() => run(() async {
        final j = await _api.panel.resumen(nombre: nombreUsuario);
        final a = Map<String, dynamic>.from(j['almacenamiento'] as Map);
        final s = Map<String, dynamic>.from(j['sincronizacion'] as Map);
        final h = Map<String, dynamic>.from(j['trabajosHpc'] as Map);

        saludo = j['saludo'] as String? ?? 'Hola';
        usadoBytes = (a['usadoBytes'] as num?)?.toInt() ?? 0;
        cuotaBytes = (a['cuotaBytes'] as num?)?.toInt() ?? 1;
        porcentaje = (a['porcentaje'] as num?)?.toInt() ?? 0;
        archivos = (a['archivos'] as num?)?.toInt() ?? 0;
        almacenamientoTexto = a['texto'] as String? ?? '';
        syncEstado = s['estado'] as String? ?? 'sincronizado';
        syncPendientes = (s['pendientes'] as num?)?.toInt() ?? 0;
        hpcEjecutando = (h['ejecutando'] as num?)?.toInt() ?? 0;
        hpcCola = (h['cola'] as num?)?.toInt() ?? 0;
        actividad = (j['actividadReciente'] as List? ?? [])
            .map((e) => ActivityItem.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
}
