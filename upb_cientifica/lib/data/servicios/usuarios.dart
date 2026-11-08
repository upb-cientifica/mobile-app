import '../api_client.dart';
import '../env.dart';
import '../session_user.dart';
import 'conversion.dart';

/// Directorio de usuarios y sesiones.
///
/// Al otro lado hay un servicio **SOAP** escrito en PHP. La app no lo sabe ni
/// tiene por qué: envía una llamada REST corriente al bus y el bus arma el
/// sobre SOAP, lo despacha y devuelve la respuesta traducida a JSON.
class ServicioUsuarios {
  ServicioUsuarios(this._api);

  final ApiClient _api;

  static const String _s = Servicios.usuarios;

  /// El usuario puede escribir "ana.torres" o el correo completo.
  static String aCorreo(String entrada) {
    final u = entrada.trim();
    return u.contains('@') ? u : '$u@${Env.dominioCorreo}';
  }

  /// Inicia sesión. Es una de las dos operaciones que el bus deja pasar sin
  /// token; devuelve el par de tokens y el perfil del usuario.
  Future<Sesion> login(String correo, String password) async {
    final d = comoMapa(await _api.post('/$_s/login', query: {
      'correo': aCorreo(correo),
      'password': password,
    }));
    final acceso = d['accessToken'] as String?;
    if (acceso == null || acceso.isEmpty) {
      throw StateError('El directorio de usuarios no devolvió un token');
    }
    return Sesion(
      accessToken: acceso,
      refreshToken: (d['refreshToken'] as String?) ?? '',
      expiraEn: comoEntero(d['expiraEn'], 900),
      // El perfil viene anidado bajo `usuario` dentro del resultado del login.
      usuario: aUsuario(comoMapa(d['usuario']).isEmpty ? d : comoMapa(d['usuario'])),
    );
  }

  /// Perfil del usuario de la sesión vigente.
  ///
  /// El bus la deja pasar con token pero sin exigir el claim `usuarios`:
  /// consultar lo propio es parte de estar autenticado, no de administrar el
  /// directorio.
  Future<SessionUser> miPerfil() async {
    final d = comoMapa(await _api.post('/$_s/miPerfil'));
    return aUsuario(comoMapa(d['usuario']).isEmpty ? d : comoMapa(d['usuario']));
  }

  Future<void> cerrarSesion() => _api.post('/$_s/cerrarSesion');

  Future<void> cambiarContrasena(String actual, String nueva) =>
      _api.post('/$_s/cambiarContrasena', query: {
        'contrasenaActual': actual,
        'contrasenaNueva': nueva,
      });

  /// Directorio completo. Requiere el claim `usuarios` (perfil administrador).
  Future<List<Map<String, dynamic>>> listarUsuarios({String busqueda = '', int tamano = 50}) async {
    final d = await _api.post('/$_s/listarUsuarios',
        query: {'q': busqueda, 'tamano': tamano});
    return listaDesde(d, ['items', 'usuarios']);
  }

  /// Sesiones abiertas: es la bitácora de acceso que lleva el directorio y lo
  /// que alimenta la pantalla de auditoría.
  Future<List<Map<String, dynamic>>> listarSesiones() async {
    final d = await _api.post('/$_s/listarSesiones');
    return listaDesde(d, ['sesiones', 'items']);
  }

  Future<void> actualizarEstado(String id, String estado) =>
      _api.post('/$_s/actualizarUsuario', query: {'id': id, 'estado': estado});
}

/// Lo que devuelve un login correcto.
class Sesion {
  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEn,
    required this.usuario,
  });

  final String accessToken;
  final String refreshToken;
  final int expiraEn;
  final SessionUser usuario;
}

/// Usuario del directorio → perfil de la app.
///
/// Se normaliza aquí y no en [SessionUser] porque la irregularidad es del
/// transporte —XML no distingue un valor de una lista de uno—, no del modelo.
SessionUser aUsuario(Map<String, dynamic> j) => SessionUser(
      id: '${j['id'] ?? ''}',
      correo: '${j['correo'] ?? ''}',
      nombre: '${j['nombre'] ?? j['correo'] ?? ''}',
      rol: '${j['rol'] ?? 'investigador'}',
      grupo: j['grupo'] as String?,
      servicios: comoTextos(j['servicios']),
      cuotaBytes: comoEntero(j['cuotaBytes']),
      usoBytes: comoEntero(j['usoBytes']),
      homePath: j['homePath'] as String?,
    );
