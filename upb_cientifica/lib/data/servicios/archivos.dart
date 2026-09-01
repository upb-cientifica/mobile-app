import '../api_client.dart';
import '../env.dart';
import 'conversion.dart';

/// Home compartido: el árbol de archivos del usuario, con permisos Unix,
/// versiones, destacados y papelera.
///
/// Habla REST, así que el bus no traduce el protocolo — pero sigue mediando:
/// la app no conoce la dirección del servicio y el bus impone la autorización y
/// la traza antes de dejar pasar el mensaje.
class ServicioArchivos {
  ServicioArchivos(this._api);

  final ApiClient _api;

  static const String _s = Servicios.archivos;

  /// Rutas que el servicio de sincronización conoce. Se consulta una vez y se
  /// reutiliza: sirve para marcar qué archivos del Home están además replicados
  /// en los dispositivos del usuario.
  Set<String>? _sincronizadas;

  Future<Set<String>> _rutasSincronizadas() async {
    if (_sincronizadas != null) return _sincronizadas!;
    try {
      final d = await _api.get('/${Servicios.sync}/archivos');
      _sincronizadas = comoLista(d).map((f) => '${f['ruta']}').toSet();
    } catch (_) {
      // El usuario puede no tener el claim `file_sync`, o el servicio puede
      // estar caído: eso no debe impedir listar el Home.
      _sincronizadas = const {};
    }
    return _sincronizadas!;
  }

  /// Olvida lo aprendido sobre sincronización (tras subir o borrar algo).
  void invalidarCache() => _sincronizadas = null;

  /// Contenido de una carpeta, ya en la forma que dibuja el explorador.
  ///
  /// El servicio identifica cada nodo por su **ruta**, no por un id opaco: aquí
  /// la ruta es el id, que además permite deducir el padre sin otra llamada.
  Future<Contenido> listar(String ruta, {String? filtro}) async {
    final d = comoMapa(await _api.get('/$_s/files', query: {'ruta': ruta}));
    final sync = await _rutasSincronizadas();

    List<Map<String, dynamic>> nodos(String clave) =>
        comoLista(d[clave]).map((n) => _aNodo(n, sync)).toList();

    // El servicio no filtra por tipo: clasifica cada nodo y el filtrado es de
    // la vista. Un filtro que no reconocemos no debe vaciar la carpeta.
    final tipos = filtro == null ? const <String>{} : _tipoDeFiltro(filtro);
    final archivos = nodos('archivos')
        .where((a) => tipos.isEmpty || tipos.contains(a['tipo']))
        .toList();

    return Contenido(
      ruta: '${d['ruta'] ?? ruta}',
      carpetas: nodos('carpetas'),
      archivos: archivos,
    );
  }

  /// Secciones transversales del Home: destacados, papelera y compartidos.
  Future<Contenido> seccion(String nombre) async {
    final d = comoMapa(await _api.get('/$_s/files', query: {'seccion': nombre}));
    final sync = await _rutasSincronizadas();
    return Contenido(
      ruta: '/',
      carpetas: comoLista(d['carpetas']).map((n) => _aNodo(n, sync)).toList(),
      archivos: comoLista(d['archivos']).map((n) => _aNodo(n, sync)).toList(),
    );
  }

  /// Lo que otros me compartieron. Llega como lista plana, ya con propietario.
  Future<List<Map<String, dynamic>>> compartidosConmigo() async {
    final d = await _api.get('/$_s/compartidos-conmigo');
    final sync = await _rutasSincronizadas();
    return comoLista(d).map((n) => _aNodo(n, sync)).toList();
  }

  /// Uso y cuota del Home: `{usadoBytes, cuotaBytes, porcentaje, archivos}`.
  Future<Map<String, dynamic>> home() async =>
      comoMapa(await _api.get('/$_s/home'));

  Future<void> crearCarpeta(String rutaPadre, String nombre) =>
      _api.post('/$_s/files/carpeta', query: {'ruta': rutaPadre, 'nombre': nombre});

  /// Sube el contenido de un archivo a [rutaPadre] con el nombre [nombre].
  Future<void> subir(String rutaPadre, String nombre, List<int> bytes) async {
    await _api.subirArchivo('/$_s/files/upload',
        query: {'ruta': rutaPadre, 'nombre': nombre}, bytes: bytes);
    invalidarCache();
  }

  /// Borrado reversible: va a la papelera salvo que se pida [definitivo].
  Future<void> eliminar(String ruta, {bool definitivo = false}) async {
    await _api.delete('/$_s/files',
        query: {'ruta': ruta, if (definitivo) 'definitivo': 'true'});
    invalidarCache();
  }

  Future<void> restaurar(String ruta) =>
      _api.post('/$_s/files/restaurar', query: {'ruta': ruta});

  Future<void> renombrar(String ruta, String nuevoNombre) =>
      _api.patch('/$_s/files', query: {'ruta': ruta, 'nuevoNombre': nuevoNombre});

  /// Sin `valor`, el servicio conmuta el destacado.
  Future<void> destacar(String ruta) =>
      _api.post('/$_s/files/destacar', query: {'ruta': ruta});

  Future<List<Map<String, dynamic>>> versiones(String ruta) async =>
      comoLista(await _api.get('/$_s/files/versiones', query: {'ruta': ruta}));

  /// Permisos del nodo: dueño, grupo, los tres tríos rwx y con quién está
  /// compartido.
  Future<Map<String, dynamic>> permisos(String ruta) async =>
      comoMapa(await _api.get('/$_s/files/permisos', query: {'ruta': ruta}));

  /// Cambia el modo Unix. Cada parámetro es un dígito octal (0..7): el servicio
  /// conserva el que no se envíe. Sólo el propietario o un administrador puede.
  Future<void> cambiarPermisos(String ruta,
          {required int owner, required int group, required int others}) =>
      _api.put('/$_s/files/permisos',
          query: {'ruta': ruta, 'owner': owner, 'group': group, 'others': others});

  Future<void> compartir(String ruta, String correo, {String permiso = 'lectura'}) =>
      _api.post('/$_s/files/compartir',
          query: {'ruta': ruta, 'correo': correo, 'permiso': permiso});

  /// Retira el acceso de [correo] al nodo.
  Future<void> dejarDeCompartir(String ruta, String correo) =>
      _api.post('/$_s/files/compartir',
          query: {'ruta': ruta, 'correo': correo, 'accion': 'revoke'});

  /// URL de descarga con el token incrustado, para abrir o previsualizar.
  Future<String> urlDescarga(String ruta) =>
      _api.urlConToken('/$_s/files/download', query: {'ruta': ruta});

  /// Nodo del servicio → la forma que consumen `FolderEntry` y `FileEntry`.
  Map<String, dynamic> _aNodo(Map<String, dynamic> n, Set<String> sync) {
    final ruta = '${n['ruta'] ?? ''}';
    return {
      // La ruta es el identificador: única, estable y con el padre implícito.
      'id': ruta,
      'ruta': ruta,
      'nombre': n['nombre'] ?? '',
      'tipo': n['tipo'] ?? 'otro',
      'esCarpeta': comoBool(n['esCarpeta']),
      'tamanoBytes': comoEntero(n['tamanoBytes']),
      'modificadoEn': n['modificadoEn'],
      'propietario': n['propietario'] ?? '',
      'grupo': n['grupo'] ?? '',
      'version': comoEntero(n['version']),
      'destacado': comoBool(n['destacado']),
      'enPapelera': comoBool(n['enPapelera']),
      'permisos': comoMapa(n['permisos']),
      'miAcceso': n['miAcceso'] ?? '',
      // El Home es el lado servidor de la sincronización; "sincronizado"
      // significa que además está replicado en los dispositivos del usuario.
      'estadoSync': sync.contains(ruta) ? 'sincronizado' : 'solo-servidor',
    };
  }

  /// Etiqueta del filtro de la interfaz → tipos que devuelve el servicio.
  static Set<String> _tipoDeFiltro(String filtro) => switch (filtro) {
        'documentos' => {'documento'},
        'imagenes' => {'imagen'},
        'videos' => {'video'},
        'codigo' => {'codigo'},
        'datasets' => {'dataset'},
        _ => const {},
      };
}

/// Contenido de una carpeta del Home.
class Contenido {
  const Contenido({required this.ruta, required this.carpetas, required this.archivos});

  final String ruta;
  final List<Map<String, dynamic>> carpetas;
  final List<Map<String, dynamic>> archivos;
}
