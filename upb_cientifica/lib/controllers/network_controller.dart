import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/api.dart';

/// Observa la conectividad y, al entrar en Wi-Fi, vuelve a leer el estado de
/// sincronización — el requisito del enunciado: «sincronizar una vez alcance
/// una conexión WIFI a la red local».
///
/// Lo que el teléfono hace al llegar a la red es **releer**, no empujar: la
/// transferencia por bloques es del cliente gRPC de escritorio, y el bus no
/// media gRPC. Lo que sí resuelve el móvil, y es lo valioso de tenerlo encima,
/// son los conflictos que hayan aparecido.
class NetworkController extends ChangeNotifier {
  NetworkController(this._api);

  final Api _api;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _onWifi = false;
  bool get onWifi => _onWifi;

  DateTime? _lastAutoSync;
  DateTime? get lastAutoSync => _lastAutoSync;

  /// Conflictos pendientes vistos en la última lectura automática.
  int conflictosPendientes = 0;

  /// Se invoca tras una lectura automática exitosa (para refrescar vistas).
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
    // Evita repetir si ya se leyó hace menos de 2 minutos.
    if (_lastAutoSync != null &&
        DateTime.now().difference(_lastAutoSync!) < const Duration(minutes: 2)) {
      return;
    }
    try {
      final estado = await _api.sync.estado();
      conflictosPendientes = (estado['pendientesTotal'] as num?)?.toInt() ?? 0;
      _lastAutoSync = DateTime.now();
      onAutoSynced?.call();
      notifyListeners();
    } catch (_) {
      // Wi-Fi que no es la del CCA, o el bus fuera de alcance: se reintenta en
      // el próximo cambio de red.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
