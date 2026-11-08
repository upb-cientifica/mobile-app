import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/sincronizacion/decisiones.dart';
import 'network_controller.dart';

/// Presenta la carpeta local, las transferencias y los conflictos del servicio.
class SyncController extends ChangeNotifier {
  SyncController(this.red) {
    red.addListener(_cambio);
    load();
  }
  final NetworkController red;
  List<String> archivos = [];
  List<Map<String, dynamic>> conflictos = [];
  String? error;
  bool loading = false;
  bool _disposed = false;
  DateTime? _ultima;
  void _avisar() {
    if (!_disposed) notifyListeners();
  }

  void _cambio() {
    if (_ultima != red.lastAutoSync) {
      _ultima = red.lastAutoSync;
      load();
    }
    _avisar();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _avisar();
    try {
      archivos = await red.motor.archivos();
      if (red.enRedInterna) conflictos = await red.auth.api.sync.conflictos();
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      _avisar();
    }
  }

  Future<void> preferencia(bool guardarTodo) async {
    try {
      await red.motor.preferencia(!guardarTodo);
    } catch (e) {
      error = '$e';
    }
    _avisar();
  }

  Future<void> agregar() async {
    try {
      final seleccion = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      if (seleccion == null) return;
      await red.motor.iniciar();
      for (final f in seleccion.files) {
        if (f.path == null || !rutaSegura(f.name) || f.name.contains('/')) {
          throw StateError('No se puede leer ${f.name}');
        }
        var destino = File('${red.motor.carpeta.path}/${f.name}');
        var n = 1;
        while (await destino.exists()) {
          destino = File('${red.motor.carpeta.path}/(${n++}) ${f.name}');
        }
        final temporal = await (await getTemporaryDirectory()).createTemp(
          'importar-sync-',
        );
        try {
          final copia = await File(f.path!).copy('${temporal.path}/contenido');
          await copia.rename(destino.path);
        } finally {
          await temporal.delete(recursive: true);
        }
      }
      await load();
      await red.sincronizar();
    } catch (e) {
      error = '$e';
      _avisar();
    }
  }

  Future<void> resolver(
    Map<String, dynamic> conflicto,
    String estrategia,
  ) async {
    try {
      await red.auth.api.sync.resolver('${conflicto['id']}', estrategia);
      await red.motor.aceptarResolucion('${conflicto['ruta']}');
      await red.sincronizar();
      await load();
    } catch (e) {
      error = '$e';
      _avisar();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    red.removeListener(_cambio);
    super.dispose();
  }
}
