import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/admin_models.dart';
import 'async_state.dart';

/// Panel de administración: cuentas del directorio, nodos del clúster y
/// sesiones abiertas.
///
/// Cruza dos servicios en tres protocolos distintos —el directorio por SOAP,
/// el clúster por RMI— y ninguno de los dos lo sabe: el bus los junta.
class AdminController extends ChangeNotifier with AsyncState {
  AdminController(this._api) {
    load();
  }

  final Api _api;

  List<AdminUserEntry> users = const [];
  int total = 0;
  List<Map<String, dynamic>> nodos = const [];
  List<Map<String, dynamic>> auditoria = const [];

  Future<void> load() => run(() async {
        // Las tres lecturas salen a la vez; se esperan en orden.
        final fUsuarios = _api.usuarios.listarUsuarios(tamano: 50);
        final fNodos = _api.hpc.nodos();
        final fSesiones = _api.usuarios.listarSesiones();

        final lista = await fUsuarios;
        users = [
          for (var i = 0; i < lista.length; i++) AdminUserEntry.fromApi(lista[i], i),
        ];
        total = users.length;

        // El clúster reporta host, ranuras y si responde; no lleva métricas por
        // nodo, así que se muestra la capacidad, que es lo que sí sabe.
        nodos = (await fNodos).map((n) => {
              'nombre': '${n['host']}',
              'estado': n['disponible'] == true ? 'activo' : 'caido',
              'slots': (n['slots'] as num?)?.toInt() ?? 0,
            }).toList();

        auditoria = await fSesiones;
      });
}
