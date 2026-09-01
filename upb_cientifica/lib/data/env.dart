import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración de entorno de la app.
///
/// La app **no conoce la dirección de ningún servicio**. Todo su tránsito entra
/// por el **Service Bus**, que resuelve dónde vive cada servicio, autoriza de
/// forma central con el claim del JWT y traduce el protocolo del destino
/// (SOAP sobre PHP, Java RMI o REST). Es la columna "Service bus" de la
/// Figura 1 del enunciado.
///
/// La dirección se puede sobreescribir en tiempo de compilación, que es como se
/// apunta a la máquina del CCA sin tocar el código:
///
///   flutter run --dart-define=BUS_URL=http://192.168.1.20:8099/bus
class Env {
  const Env._();

  static const String _override =
      String.fromEnvironment('BUS_URL', defaultValue: '');

  /// URL base del Service Bus.
  static String get busUrl {
    if (_override.isNotEmpty) return _override;
    // En el emulador de Android, `localhost` del host es 10.0.2.2.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8099/bus';
    return 'http://localhost:8099/bus';
  }

  /// Dominio que se añade cuando en el login se escribe sólo el nombre de cuenta.
  static const String dominioCorreo = 'upb.edu.co';

  /// Nombre esperado de la red local del CCA (para el disparo de sincronización).
  static const String redLocalUpb = 'UPB-CCA';
}

/// Códigos de servicio tal como están registrados en el bus y como viajan en el
/// claim `servicios` del JWT. Toda ruta que sale de la app empieza por uno de
/// estos: `/{servicio}/{operación}`.
class Servicios {
  const Servicios._();

  /// Directorio de usuarios y sesiones. El bus arma el sobre SOAP.
  static const String usuarios = 'usuarios';

  /// Home compartido: archivos, cuotas, permisos Unix, versiones.
  static const String archivos = 'shared_file';

  /// Álbum de fotos del Home.
  static const String fotos = 'photo_album';

  /// Difusión de video (catálogo + HLS).
  static const String video = 'streaming';

  /// Sincronización de archivos. Habla gRPC con su cliente de escritorio y
  /// publica una cara REST para consultas, que es la que media el bus.
  static const String sync = 'file_sync';

  /// Clúster de cómputo. El bus invoca el objeto remoto por Java RMI.
  static const String hpc = 'hpc';

  /// Monitoreo: disponibilidad, métricas de máquina y alertas.
  static const String monitoreo = 'monitoreo';
}
