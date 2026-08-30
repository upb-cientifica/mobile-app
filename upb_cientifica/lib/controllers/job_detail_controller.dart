import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import 'async_state.dart';

class JobDetailController extends ChangeNotifier with AsyncState {
  JobDetailController(this._api, this.jobId) {
    load();
  }

  final ApiClient _api;
  final String jobId;

  static const List<String> tabs = ['Registro', 'Salida', 'Errores', 'Resultados', 'Métricas'];
  String _tab = tabs.first;
  String get tab => _tab;

  Map<String, dynamic> job = const {};
  List<Map<String, dynamic>> eventos = const [];
  List<String> salida = const [];
  List<String> errores = const [];
  List<Map<String, dynamic>> resultados = const [];

  Future<void> load() => run(() async {
        final j = Map<String, dynamic>.from(await _api.get('/hpc/trabajos/$jobId') as Map);
        job = j;
        eventos = (j['eventos'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        salida = (j['salidaEstandar'] as List? ?? []).map((e) => '$e').toList();
        errores = (j['errores'] as List? ?? []).map((e) => '$e').toList();
        resultados = (j['resultados'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });

  void setTab(String tab) {
    _tab = tab;
    notifyListeners();
  }

  Future<void> cancel() async {
    await _api.post('/hpc/trabajos/$jobId/cancelar');
    await load();
  }

  Future<void> rerun() => _api.post('/hpc/trabajos/$jobId/reejecutar');
}
