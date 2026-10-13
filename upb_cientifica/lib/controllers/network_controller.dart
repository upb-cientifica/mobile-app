import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../data/sincronizacion/motor.dart';
import 'auth_controller.dart';

/// Comprueba la red interna y sincroniza mientras la aplicación esté activa.
class NetworkController extends ChangeNotifier with WidgetsBindingObserver {
  NetworkController(this.auth) : motor = MotorSincronizacion(auth.api.sync);
  final AuthController auth;
  final MotorSincronizacion motor;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;
  bool onWifi = false;
  bool enRedInterna = false;
  bool _red = false, _activo = true, _ocupado = false, _disposed = false;
  bool get ocupado => _ocupado;
  ResumenSync? resumen;
  DateTime? lastAutoSync;
  int _generacion = 0;
  bool get _habilitado =>
      !_disposed && _activo && _red && auth.stage == AuthStage.conectado;

  Future<void> start() async {
    _activo =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(_sesion);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => sincronizar());
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      /* sin red */
    }
  }

  void _avisar() {
    if (!_disposed) notifyListeners();
  }

  void _sesion() {
    if (auth.stage != AuthStage.conectado) {
      _generacion++;
      enRedInterna = false;
    }
    _avisar();
    if (_habilitado) unawaited(sincronizar());
  }

  void _apply(List<ConnectivityResult> results) {
    if (_disposed) return;
    _generacion++;
    onWifi = results.contains(ConnectivityResult.wifi);
    _red = onWifi || results.contains(ConnectivityResult.ethernet);
    enRedInterna = false;
    _avisar();
    unawaited(sincronizar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activo = state == AppLifecycleState.resumed;
    if (!_activo) _generacion++;
    if (_activo) {
      _connectivity.checkConnectivity().then(_apply).catchError((Object _) {});
    }
  }

  Future<void> sincronizar() async {
    if (!_habilitado || _ocupado) return;
    _ocupado = true;
    final generacion = _generacion;
    bool vigente() => _habilitado && generacion == _generacion;
    _avisar();
    try {
      await auth.api.sync.comprobarRed();
      if (!vigente()) return;
      enRedInterna = true;
      _avisar();
      resumen = await motor.sincronizar(vigente: vigente);
      lastAutoSync = DateTime.now();
    } catch (_) {
      enRedInterna = false;
    } finally {
      _ocupado = false;
      _avisar();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    auth.removeListener(_sesion);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
