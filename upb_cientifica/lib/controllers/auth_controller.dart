import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/api_exception.dart';
import '../data/servicios/usuarios.dart';
import '../data/session_user.dart';
import '../data/token_store.dart';

enum AuthStage { comprobando, desconectado, mfaPendiente, conectado }

/// Controlador de sesión de la app: login, perfil vigente y cierre de sesión.
/// Vive a nivel de aplicación y es el dueño del [Api] que usan los demás.
///
/// La autenticación la resuelve el **directorio de usuarios**, un servicio SOAP
/// al que se llega por el bus. El token que devuelve es el mismo que verifican
/// todos los demás servicios: hay una sola autoridad de identidad en el sistema.
class AuthController extends ChangeNotifier {
  AuthController({Api? api, TokenStore? tokens})
      : _tokens = tokens ?? TokenStore(),
        _api = api ?? Api() {
    _api.onSessionExpired = _onExpired;
  }

  final Api _api;
  final TokenStore _tokens;

  Api get api => _api;

  AuthStage _stage = AuthStage.comprobando;
  AuthStage get stage => _stage;

  SessionUser? _user;
  SessionUser? get user => _user;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool _rememberDevice = false;

  /// Restaura la sesión al arrancar la app.
  Future<void> bootstrap() async {
    _stage = AuthStage.comprobando;
    notifyListeners();
    if (await _tokens.hasSession) {
      try {
        _user = await _api.usuarios.miPerfil();
        _stage = AuthStage.conectado;
      } catch (_) {
        await _tokens.clear();
        _stage = AuthStage.desconectado;
      }
    } else {
      _stage = AuthStage.desconectado;
    }
    notifyListeners();
  }

  /// Valida correo/contraseña contra el directorio y abre la sesión.
  Future<void> login(String correo, String password,
      {bool rememberDevice = false}) async {
    _setBusy(true);
    _rememberDevice = rememberDevice;
    try {
      await _persistSession(await _api.usuarios.login(correo, password));
    } on ApiException catch (e) {
      _error = e.esCredenciales || e.status == 401
          ? 'Correo o contraseña incorrectos'
          : e.mensaje;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// El directorio autentica con token y no tiene segundo factor: no hay
  /// servidor de autenticación aparte al que pedirle un código. La etapa
  /// [AuthStage.mfaPendiente] queda declarada pero nunca se entra en ella.
  Future<void> verifyMfa(String codigo) async {
    _error = 'El sistema autentica con token; no hay verificación en dos pasos.';
    notifyListeners();
    throw ApiException(_error!);
  }

  Future<void> logout() async {
    try {
      await _api.usuarios.cerrarSesion();
    } catch (_) {/* idempotente: la sesión local se cierra igual */}
    await _tokens.clear();
    _user = null;
    _stage = AuthStage.desconectado;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      _user = await _api.usuarios.miPerfil();
      notifyListeners();
    } catch (_) {/* mantiene el perfil previo */}
  }

  Future<void> _persistSession(Sesion s) async {
    await _tokens.save(access: s.accessToken, refresh: s.refreshToken);
    _user = s.usuario;
    _stage = AuthStage.conectado;
    notifyListeners();
    // ignore: unnecessary_statements
    _rememberDevice; // reservado para persistir el dispositivo de confianza
  }

  void _onExpired() {
    _user = null;
    _stage = AuthStage.desconectado;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    if (value) _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}
