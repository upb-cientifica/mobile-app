import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/service_status.dart';
import 'async_state.dart';

class MonitoringController extends ChangeNotifier with AsyncState {
  MonitoringController(this._api) {
    load();
  }

  final ApiClient _api;

  MonitoringSummary? summary;

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/monitoreo') as Map);
        summary = MonitoringSummary.fromApi(j);
      });
}
