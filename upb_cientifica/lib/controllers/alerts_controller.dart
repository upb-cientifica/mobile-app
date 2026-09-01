import 'package:flutter/foundation.dart';

import '../data/alertas_leidas.dart';
import '../data/api.dart';
import '../models/alert_item.dart';
import 'async_state.dart';

/// Alertas del sistema.
///
/// Vienen del Monitoreo, que evalúa reglas de umbral sobre las métricas y las
/// sondas de disponibilidad. El estado "leída" no viene de allí —es de esta
/// persona en este teléfono— y lo lleva [AlertasLeidas].
class AlertsController extends ChangeNotifier with AsyncState {
  AlertsController(this._api, {AlertasLeidas? leidas})
      : _leidas = leidas ?? AlertasLeidas() {
    load();
  }

  final Api _api;
  final AlertasLeidas _leidas;

  String _filter = 'Todos';
  List<AlertItem> _alerts = const [];
  int _unread = 0;

  String get filter => _filter;
  List<AlertItem> get alerts => _alerts;
  List<AlertItem> get filteredAlerts => _alerts;
  int get unreadCount => _unread;

  Future<void> load() => run(() async {
        final crudas = await _api.monitoreo.alertas(
          categoria: alertFilterToCategoria(_filter),
        );
        final vistas = await _leidas.leidas();
        _alerts = crudas
            .map((a) => AlertItem.fromApi({...a, 'leida': vistas.contains('${a['id']}')}))
            .toList();
        _unread = _alerts.where((a) => !a.read).length;
      });

  void setFilter(String filter) {
    _filter = filter;
    load();
  }

  Future<void> markAllRead() async {
    await _leidas.marcar(_alerts.map((a) => a.id));
    await load();
  }

  Future<void> markRead(String id) async {
    await _leidas.marcar([id]);
    await load();
  }
}
