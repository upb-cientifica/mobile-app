import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/api_client.dart';

/// Observa la conectividad y, al detectar Wi-Fi (la red local del CCA),
/// dispara automáticamente la sincronización — requisito del enunciado:
/// «sincronizar una vez alcance una conexión WIFI a la red local».
class NetworkController extends ChangeNotifier {
  NetworkController(this._api);

  final ApiClient _api;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _onWifi = false;
  bool get onWifi => _onWifi;

  DateTime? _lastAutoSync;
  DateTime? get lastAutoSync => _lastAutoSync;

  /// Se invoca tras una sincronización automática exitosa (para refrescar vistas).
  void Function()? onAutoSynced;

  Future<void> start() async {
    _apply(await _connectivity.checkConnectivity());
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final wifi = results.contains(ConnectivityResult.wifi);
    final changedToWifi = wifi && !_onWifi;
    _onWifi = wifi;
    notifyListeners();
    if (changedToWifi) _autoSync();
  }

  Future<void> _autoSync() async {
    // Evita repetir si ya se sincronizó hace menos de 2 minutos.
    if (_lastAutoSync != null &&
        DateTime.now().difference(_lastAutoSync!) < const Duration(minutes: 2)) {
      return;
    }
    try {
      await _api.post('/sync/ahora');
      _lastAutoSync = DateTime.now();
      onAutoSynced?.call();
      notifyListeners();
    } catch (_) {/* se reintenta en el próximo cambio de red */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
