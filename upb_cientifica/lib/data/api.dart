import 'api_client.dart';
import 'servicios/archivos.dart';
import 'servicios/fotos.dart';
import 'servicios/hpc.dart';
import 'servicios/monitoreo.dart';
import 'servicios/panel.dart';
import 'servicios/sincronizacion.dart';
import 'servicios/usuarios.dart';
import 'servicios/video.dart';
import 'token_store.dart';

/// Todo lo que la app puede pedirle al sistema, en un solo objeto.
///
/// Detrás hay siete servicios en cuatro lenguajes hablando tres protocolos
/// distintos, repartidos por las máquinas del CCA. La app no conoce ninguna de
/// esas direcciones ni ninguno de esos protocolos: habla con el **Service Bus**
/// y el bus se encarga del resto.
///
/// Cada propiedad es un servicio del registro del bus; `panel` es la excepción
/// —resume varios— y por eso vive aquí y no en un backend intermedio.
class Api {
  Api({TokenStore? tokenStore})
      : cliente = ApiClient(tokenStore: tokenStore ?? TokenStore()) {
    usuarios = ServicioUsuarios(cliente);
    archivos = ServicioArchivos(cliente);
    fotos = ServicioFotos(cliente);
    video = ServicioVideo(cliente);
    sync = ServicioSincronizacion(cliente);
    hpc = ServicioHpc(cliente);
    monitoreo = ServicioMonitoreo(cliente, hpc);
    panel = ServicioPanel(archivos, sync, hpc);
  }

  /// El transporte. Sólo la sesión debería necesitarlo directamente.
  final ApiClient cliente;

  late final ServicioUsuarios usuarios;
  late final ServicioArchivos archivos;
  late final ServicioFotos fotos;
  late final ServicioVideo video;
  late final ServicioSincronizacion sync;
  late final ServicioHpc hpc;
  late final ServicioMonitoreo monitoreo;
  late final ServicioPanel panel;

  set onSessionExpired(void Function()? f) => cliente.onSessionExpired = f;

  void close() => cliente.close();
}
