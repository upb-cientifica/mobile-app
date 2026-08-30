import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_exception.dart';
import '../data/session_user.dart';
import '../data/token_store.dart';

enum AuthStage { comprobando, desconectado, mfaPendiente, conectado }

/// Controlador de sesión de la app: login, verificación en dos pasos,
/// perfil vigente y cierre de sesión. Vive a nivel de aplicación.
class AuthController extends ChangeNotifier {
  AuthController({ApiClient? api, TokenStore? tokens})
      : _tokens = tokens ?? TokenStore(),
        _api = api ?? ApiClient() {
    _api.onSessionExpired = _onExpired;
  }

  final ApiClient _api;
  final TokenStore _tokens;

  ApiClient get api => _api;

  AuthStage _stage = AuthStage.comprobando;
  AuthStage get stage => _stage;

  SessionUser? _user;
  SessionUser? get user => _user;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  // Guarda las credenciales entre login y verificación MFA.
  String? _pendingEmail;
  String? _pendingPassword;
  bool _rememberDevice = false;

  /// Restaura la sesión al arrancar la app.
  Future<void> bootstrap() async {
    _stage = AuthStage.comprobando;
    notifyListeners();
    if (await _tokens.hasSession) {
      try {
        _user = SessionUser.fromJson(
            Map<String, dynamic>.from(await _api.get('/auth/me') as Map));
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

  /// Paso 1: valida correo/contraseña contra el BFF.
  Future<void> login(String correo, String password,
      {bool rememberDevice = false}) async {
    _setBusy(true);
    _rememberDevice = rememberDevice;
    try {
      final data = Map<String, dynamic>.from(
        await _api.post('/auth/login',
            body: {'correo': correo.trim(), 'password': password}) as Map,
      );
      // El BFF puede pedir un segundo factor; si no, entrega tokens directo.
      if (data['requiereMfa'] == true) {
        _pendingEmail = correo.trim();
        _pendingPassword = password;
        _stage = AuthStage.mfaPendiente;
      } else {
        await _persistSession(data);
      }
    } on ApiException catch (e) {
      _error = e.esCredenciales
          ? 'Correo o contraseña incorrectos'
          : e.mensaje;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Paso 2 (si aplica): reenvía las credenciales con el código de 6 dígitos.
  /// Mientras el Authentication Server no exista, el BFF acepta el login sin
  /// segundo factor y este paso simplemente completa la sesión.
  Future<void> verifyMfa(String codigo) async {
    _setBusy(true);
    try {
      final data = Map<String, dynamic>.from(
        await _api.post('/auth/login', body: {
          'correo': _pendingEmail,
          'password': _pendingPassword,
          'codigoMfa': codigo,
        }) as Map,
      );
      await _persistSession(data);
    } on ApiException catch (e) {
      _error = e.mensaje;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {/* idempotente */}
    await _tokens.clear();
    _user = null;
    _pendingEmail = _pendingPassword = null;
    _stage = AuthStage.desconectado;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      _user = SessionUser.fromJson(
          Map<String, dynamic>.from(await _api.get('/auth/me') as Map));
      notifyListeners();
    } catch (_) {/* mantiene el perfil previo */}
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    final u = data['usuario'];
    _user = u is Map
        ? SessionUser.fromJson(Map<String, dynamic>.from(u))
        : SessionUser.fromJson(
            Map<String, dynamic>.from(await _api.get('/auth/me') as Map));
    _pendingEmail = _pendingPassword = null;
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
