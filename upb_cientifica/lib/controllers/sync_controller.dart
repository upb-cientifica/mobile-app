import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/sync_item.dart';
import 'async_state.dart';

class SyncController extends ChangeNotifier with AsyncState {
  SyncController(this._api) {
    load();
  }

  final ApiClient _api;

  SyncState? state;
  List<SyncItem> get items => state?.items ?? const [];

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/sync') as Map);
        state = SyncState.fromApi(j);
      });

  Future<void> syncNow() async {
    await run(() async {
      final j = Map<String, dynamic>.from(await _api.post('/sync/ahora') as Map);
      state = SyncState.fromApi(j);
    });
  }

  Future<void> pause() async {
    await run(() async {
      final j = Map<String, dynamic>.from(await _api.post('/sync/pausar') as Map);
      state = SyncState.fromApi(j);
    });
  }
}
