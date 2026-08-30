import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../models/admin_models.dart';
import 'async_state.dart';

class AdminController extends ChangeNotifier with AsyncState {
  AdminController(this._api) {
    load();
  }

  final ApiClient _api;

  List<AdminUserEntry> users = const [];
  int total = 0;
  List<Map<String, dynamic>> nodos = const [];
  List<Map<String, dynamic>> auditoria = const [];

  Future<void> load() => run(() async {
        final results = await Future.wait([
          _api.get('/admin/usuarios', query: {'tamano': 20}),
          _api.get('/admin/nodos'),
          _api.get('/admin/auditoria', query: {'limite': 15}),
        ]);
        final lista = results[0] as List;
        users = [
          for (var i = 0; i < lista.length; i++)
            AdminUserEntry.fromApi(Map<String, dynamic>.from(lista[i] as Map), i),
        ];
        total = users.length;
        nodos = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        auditoria = (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
}
