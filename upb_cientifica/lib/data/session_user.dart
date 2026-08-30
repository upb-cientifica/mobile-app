/// Usuario autenticado tal como lo devuelve el BFF (`/auth/login`, `/auth/me`).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.correo,
    required this.nombre,
    required this.rol,
    this.grupo,
    this.servicios = const [],
    this.cuotaBytes = 0,
    this.usoBytes = 0,
    this.homePath,
  });

  final String id;
  final String correo;
  final String nombre;
  final String rol;
  final String? grupo;
  final List<String> servicios;
  final int cuotaBytes;
  final int usoBytes;
  final String? homePath;

  bool get esAdmin => rol == 'admin';
  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;
  bool tieneServicio(String codigo) => servicios.contains(codigo);

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: '${j['id']}',
        correo: j['correo'] as String? ?? '',
        nombre: j['nombre'] as String? ?? '',
        rol: j['rol'] as String? ?? 'investigador',
        grupo: j['grupo'] as String?,
        servicios:
            (j['servicios'] as List?)?.map((e) => '$e').toList() ?? const [],
        cuotaBytes: (j['cuotaBytes'] as num?)?.toInt() ?? 0,
        usoBytes: (j['usoBytes'] as num?)?.toInt() ?? 0,
        homePath: j['homePath'] as String?,
      );
}
