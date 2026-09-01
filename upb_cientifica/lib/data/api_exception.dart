/// Error de una llamada al Service Bus. `codigo` viene del cuerpo
/// `{ "error": { "codigo", "mensaje" } }` cuando está disponible.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.status, this.codigo, this.correlacion});

  final String mensaje;
  final int? status;
  final String? codigo;

  /// Número de correlación que el bus asignó al mensaje (`X-Bus-Correlacion`).
  /// Con él se localiza la línea exacta en la bitácora del bus.
  final String? correlacion;

  bool get esNoAutorizado => status == 401 || codigo == 'NO_AUTORIZADO' || codigo == 'TOKEN_EXPIRADO';
  bool get esCredenciales => codigo == 'CREDENCIALES';
  bool get esRed => status == null;

  /// El claim `servicios` del usuario no incluye el servicio pedido: el bus
  /// cortó la llamada antes de que saliera hacia el destino.
  bool get esProhibido => status == 403 || codigo == 'PROHIBIDO';

  @override
  String toString() => mensaje;
}
