import 'package:flutter/material.dart';

import '../data/api_client.dart';

/// Controlador del asistente de creación de trabajos HPC (4 pasos).
class CreateJobController extends ChangeNotifier {
  CreateJobController(this._api);

  final ApiClient _api;

  static const int totalSteps = 4;

  int _step = 0;
  int get step => _step;
  bool get isLastStep => _step == totalSteps - 1;

  final nombre = TextEditingController();
  final descripcion = TextEditingController();
  final proyecto = TextEditingController();
  String lenguaje = 'C';
  int procesosMpi = 8;
  int nucleos = 8;
  int memoriaMb = 4096;
  int tiempoMaxMin = 60;
  String prioridad = 'normal';

  bool _submitting = false;
  bool get submitting => _submitting;
  String? error;

  void setLenguaje(String v) {
    lenguaje = v;
    notifyListeners();
  }

  void setPrioridad(String v) {
    prioridad = v;
    notifyListeners();
  }

  void setNumber({int? mpi, int? cores, int? mem, int? time}) {
    if (mpi != null) procesosMpi = mpi;
    if (cores != null) nucleos = cores;
    if (mem != null) memoriaMb = mem;
    if (time != null) tiempoMaxMin = time;
    notifyListeners();
  }

  bool next() {
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
      notifyListeners();
    }
  }

  void reset() {
    _step = 0;
    error = null;
    notifyListeners();
  }

  /// Envía el trabajo al clúster. Devuelve true si se creó.
  Future<bool> submit() async {
    _submitting = true;
    error = null;
    notifyListeners();
    try {
      await _api.post('/hpc/trabajos', body: {
        'nombre': nombre.text.trim(),
        if (descripcion.text.trim().isNotEmpty) 'descripcion': descripcion.text.trim(),
        if (proyecto.text.trim().isNotEmpty) 'proyecto': proyecto.text.trim(),
        'lenguaje': lenguaje,
        'procesosMpi': procesosMpi,
        'nucleos': nucleos,
        'memoriaMb': memoriaMb,
        'tiempoMaxMin': tiempoMaxMin,
        'prioridad': prioridad,
      });
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
    descripcion.dispose();
    proyecto.dispose();
    super.dispose();
  }
}
