import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/service_status.dart';
import 'async_state.dart';

/// Monitoreo del sistema. El resumen cruza dos servicios: las métricas de
/// máquina y la disponibilidad salen del Monitoreo por REST, y los nodos y
/// trabajos del clúster por Java RMI. Las dos entradas pasan por el bus.
class MonitoringController extends ChangeNotifier with AsyncState {
  MonitoringController(this._api) {
    load();
  }

  final Api _api;

  MonitoringSummary? summary;

  Future<void> load() => run(() async {
        summary = MonitoringSummary.fromApi(await _api.monitoreo.resumen());
      });
}
