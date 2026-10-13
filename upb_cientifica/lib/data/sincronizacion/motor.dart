import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../servicios/sincronizacion.dart';
import 'decisiones.dart';

class ResumenSync {
  int subidos = 0, descargados = 0, borrados = 0, conflictos = 0;
  final List<String> fallos = [];
  @override
  String toString() =>
      '$subidos subidos · $descargados descargados · '
      '$borrados borrados · $conflictos conflictos · ${fallos.length} fallos';
}

/// Mantiene una base confirmada por ruta; los cambios pendientes nunca se pisan.
class MotorSincronizacion {
  MotorSincronizacion(this.servicio);
  final ServicioSincronizacion servicio;
  late Directory carpeta;
  late File _estado;
  String dispositivoId = '';
  bool sinCopiaLocal = false;
  final Map<String, dynamic> _entradas = {};
  Future<void>? _inicio;
  Future<ResumenSync>? _pasada;
  bool get ocupado => _pasada != null;

  Future<void> iniciar() => _inicio ??= _cargar();
  Future<void> _cargar() async {
    carpeta = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/Sincronizados',
    );
    await carpeta.create(recursive: true);
    final soporte = await getApplicationSupportDirectory();
    await soporte.create(recursive: true);
    _estado = File('${soporte.path}/estado-sincronizacion.json');
    if (await _estado.exists()) {
      final j = jsonDecode(await _estado.readAsString()) as Map;
      dispositivoId = j['dispositivoId'] as String? ?? '';
      sinCopiaLocal = j['sinCopiaLocal'] == true;
      _entradas.addAll(Map<String, dynamic>.from(j['entradas'] as Map? ?? {}));
    }
  }

  Future<void> _guardar() async {
    final tmp = File('${_estado.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'dispositivoId': dispositivoId,
        'sinCopiaLocal': sinCopiaLocal,
        'entradas': _entradas,
      }),
      flush: true,
    );
    await tmp.rename(_estado.path);
  }

  Future<void> preferencia(bool sinCopia) async {
    await iniciar();
    if (_pasada != null) await _pasada;
    sinCopiaLocal = sinCopia;
    await _guardar();
  }

  /// La resolución explícita autoriza reemplazar esta copia por la del servidor.
  Future<void> aceptarResolucion(String ruta) async {
    await iniciar();
    if (_pasada != null) await _pasada;
    final local = await _local(ruta);
    if (local == null) {
      _entradas.remove(ruta);
    } else {
      _entradas[ruta] = {...local, 'version': 0};
    }
    await _guardar();
  }

  Future<List<String>> archivos() async {
    await iniciar();
    final rutas = <String>[];
    await for (final f in carpeta.list(recursive: true, followLinks: false)) {
      if (f is File) rutas.add(f.path.substring(carpeta.path.length + 1));
    }
    return rutas..sort();
  }

  Future<File> _archivo(String ruta) async {
    if (!rutaSegura(ruta)) throw StateError('Ruta no válida: $ruta');
    var actual = carpeta.path;
    for (final segmento in ruta.split('/')) {
      actual = '$actual/$segmento';
      if (await FileSystemEntity.type(actual, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('No se sincronizan enlaces: $ruta');
      }
    }
    return File(actual);
  }

  Future<Map<String, dynamic>?> _local(String ruta) async {
    final f = await _archivo(ruta);
    if (!await f.exists()) return null;
    final stat = await f.stat();
    final previo = _entradas[ruta];
    final mtime = stat.modified.microsecondsSinceEpoch;
    final hash =
        previo != null &&
            previo['tamano'] == stat.size &&
            previo['mtime'] == mtime
        ? previo['hash']
        : (await sha256.bind(f.openRead()).first).toString();
    return {'hash': hash, 'tamano': stat.size, 'mtime': mtime};
  }

  Future<ResumenSync> sincronizar({bool Function()? vigente}) {
    return _pasada ??= _ejecutar(
      vigente ?? () => true,
    ).whenComplete(() => _pasada = null);
  }

  Future<ResumenSync> _ejecutar(bool Function() vigente) async {
    final r = ResumenSync();
    void comprobar() {
      if (!vigente()) {
        throw StateError('Sincronización detenida: sesión o red no disponible');
      }
    }

    try {
      await iniciar();
      comprobar();
      if (dispositivoId.isEmpty) {
        dispositivoId = await servicio.registrar(carpeta.path);
        await _guardar();
      }
      // Si falla el listado no se interpretan archivos inaccesibles como borrados.
      final rutas = {...await archivos(), ..._entradas.keys};
      final bloqueadas = <String>{};
      for (final ruta in rutas) {
        comprobar();
        try {
          final li = await _local(ruta);
          final previo = _entradas[ruta];
          final borrar = li == null && previo != null;
          if (!borrar &&
              !debeSubir(li?['hash'] as String?, previo?['hash'] as String?)) {
            continue;
          }
          final res = borrar
              ? await servicio.eliminar(
                  ruta,
                  previo['version'] as int,
                  dispositivoId,
                )
              : await servicio.subir(
                  ruta,
                  await _archivo(ruta),
                  previo?['version'] as int? ?? 0,
                  li!['hash'] as String,
                  dispositivoId,
                );
          if (res['resultado'] == 'CONFLICTO') {
            r.conflictos++;
            bloqueadas.add(ruta);
            continue;
          }
          if (!['APLICADO', 'SIN_CAMBIOS'].contains(res['resultado'])) {
            throw StateError('Respuesta de sincronización no válida');
          }
          if (borrar) {
            _entradas.remove(ruta);
            r.borrados++;
          } else {
            _entradas[ruta] = {
              ...li!,
              'version': (res['entrada']['version'] as num).toInt(),
            };
            if (res['resultado'] == 'APLICADO') r.subidos++;
          }
          await _guardar();
        } catch (e) {
          bloqueadas.add(ruta);
          r.fallos.add('$ruta: $e');
        }
      }
      comprobar();
      final manifiesto = await servicio.manifiesto();
      for (final remoto in manifiesto) {
        comprobar();
        final ruta = remoto['ruta'] as String;
        if (bloqueadas.contains(ruta)) continue;
        try {
          final destino = await _archivo(ruta);
          final li = await _local(ruta);
          final previo = _entradas[ruta];
          final hash = li?['hash'] as String?;
          final anterior = previo?['hash'] as String?;
          final version = (remoto['version'] as num).toInt();
          if (remoto['borrado'] == true) {
            if (version >= (previo?['version'] as int? ?? 0) &&
                debeBorrarLocal(hash, anterior)) {
              await destino.delete();
              _entradas.remove(ruta);
              r.borrados++;
              await _guardar();
            }
            continue;
          }
          if (!debeBajar(
            sinCopiaLocal: sinCopiaLocal,
            local: hash,
            previo: anterior,
            base: previo?['version'] as int? ?? 0,
            version: version,
            remoto: remoto['hash'] as String,
          )) {
            continue;
          }
          if (hash != remoto['hash']) {
            final temporales = await Directory(
              '${_estado.parent.path}/descarga-',
            ).createTemp();
            try {
              final tmp = File('${temporales.path}/contenido');
              await servicio.descargar(ruta, tmp, version);
              if ((await sha256.bind(tmp.openRead()).first).toString() !=
                  remoto['hash']) {
                throw StateError('Hash de descarga incorrecto');
              }
              comprobar();
              if ((await _local(ruta))?['hash'] != hash) {
                throw StateError('El archivo cambió durante la descarga');
              }
              await destino.parent.create(recursive: true);
              await tmp.rename(destino.path);
            } finally {
              await temporales.delete(recursive: true);
            }
            r.descargados++;
          }
          _entradas[ruta] = {...(await _local(ruta))!, 'version': version};
          await _guardar();
        } catch (e) {
          r.fallos.add('$ruta: $e');
        }
      }
    } catch (e) {
      r.fallos.add('$e');
    }
    return r;
  }
}
