import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/alert_item.dart';
import 'async_state.dart';

class AlertsController extends ChangeNotifier with AsyncState {
  AlertsController(this._api) {
    load();
  }

  final ApiClient _api;

  String _filter = 'Todos';
  List<AlertItem> _alerts = const [];
  int _unread = 0;

  String get filter => _filter;
  List<AlertItem> get alerts => _alerts;
  List<AlertItem> get filteredAlerts => _alerts;
  int get unreadCount => _unread;

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/alertas',
            query: {'categoria': alertFilterToCategoria(_filter)}) as Map);
        _alerts = (j['alertas'] as List? ?? [])
            .map((e) => AlertItem.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList();
        _unread = (j['noLeidas'] as num?)?.toInt() ?? 0;
      });

  void setFilter(String filter) {
    _filter = filter;
    load();
  }

  Future<void> markAllRead() async {
    await _api.post('/alertas/marcar-todas');
    await load();
  }

  Future<void> markRead(String id) async {
    await _api.post('/alertas/$id/leer');
    await load();
  }
}
