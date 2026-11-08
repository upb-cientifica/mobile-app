import 'package:flutter/material.dart';

import '../data/api.dart';

/// Asistente de envío de un trabajo al clúster (4 pasos).
///
/// El clúster recibe lo que espera `mpirun`: un **comando** con sus argumentos,
/// el **número de procesos** y la **carpeta del Home** de donde tomar el código
/// y los datos. No recibe lenguajes ni cuotas de memoria: el planificador
/// reparte por ranuras de nodo, así que pedir esos datos sería pedirlos para
/// tirarlos.
class CreateJobController extends ChangeNotifier {
  CreateJobController(this._api) {
    _cargarSlots();
  }

  final Api _api;

  static const int totalSteps = 4;

  int _step = 0;
  int get step => _step;
  bool get isLastStep => _step == totalSteps - 1;

  final nombre = TextEditingController();
  final comando = TextEditingController();
  final rutaHome = TextEditingController(text: '/');
  int procesos = 4;

  /// Ranuras libres ahora mismo en el clúster, para no pedir más de las que hay.
  int? slotsDisponibles;

  bool _submitting = false;
  bool get submitting => _submitting;
  String? error;

  Future<void> _cargarSlots() async {
    try {
      slotsDisponibles = await _api.hpc.slotsDisponibles();
      notifyListeners();
    } catch (_) {/* el clúster puede estar caído; el formulario sigue sirviendo */}
  }

  void setProcesos(int v) {
    procesos = v.clamp(1, 256);
    notifyListeners();
  }

  /// Qué falta para poder avanzar del paso actual; null si está completo.
  String? get faltante => switch (_step) {
        0 => nombre.text.trim().isEmpty ? 'Ponle un nombre al trabajo' : null,
        1 => comando.text.trim().isEmpty ? 'Indica el programa a ejecutar' : null,
        _ => null,
      };

  /// Avanza un paso. Devuelve true cuando toca enviar.
  bool next() {
    final falta = faltante;
    if (falta != null) {
      error = falta;
      notifyListeners();
      return false;
    }
    error = null;
    if (_step < totalSteps - 1) {
      _step++;
      notifyListeners();
      return false;
    }
    return true;
  }

  void back() {
    if (_step > 0) {
      _step--;
      error = null;
      notifyListeners();
    }
  }

  void reset() {
    _step = 0;
    error = null;
    nombre.clear();
    comando.clear();
    rutaHome.text = '/';
    procesos = 4;
    notifyListeners();
  }

  /// Encola el trabajo. Devuelve true si el clúster lo aceptó.
  Future<bool> submit() async {
    _submitting = true;
    error = null;
    notifyListeners();
    try {
      await _api.hpc.enviar(
        nombre: nombre.text.trim(),
        comando: comando.text.trim(),
        procesos: procesos,
        rutaHome: rutaHome.text.trim(),
      );
      return true;
    } catch (e) {
      error = '$e';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nombre.dispose();
    comando.dispose();
    rutaHome.dispose();
    super.dispose();
  }
}
