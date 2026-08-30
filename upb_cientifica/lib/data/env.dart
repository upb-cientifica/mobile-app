import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración de entorno de la app.
///
/// La URL del BFF se puede sobreescribir en tiempo de compilación:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8090/api/v1
class Env {
  const Env._();

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// URL base del BFF (`mobile-bff`).
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    // En el emulador de Android, `localhost` del host es 10.0.2.2.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8090/api/v1';
    }
    return 'http://localhost:8090/api/v1';
  }

  /// Nombre esperado de la red local del CCA (para el disparo de sincronización).
  static const String redLocalUpb = 'UPB-CCA';
}
