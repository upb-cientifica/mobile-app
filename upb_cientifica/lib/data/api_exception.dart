/// Error de una llamada al BFF. `codigo` viene del cuerpo
/// `{ "error": { "codigo", "mensaje" } }` cuando está disponible.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.status, this.codigo});

  final String mensaje;
  final int? status;
  final String? codigo;

  bool get esNoAutorizado => status == 401 || codigo == 'NO_AUTORIZADO' || codigo == 'TOKEN_EXPIRADO';
  bool get esCredenciales => codigo == 'CREDENCIALES';
  bool get esRed => status == null;

  @override
  String toString() => mensaje;
}
