import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../models/sync_item.dart';
import 'async_state.dart';

/// Centro de sincronización.
///
/// El servicio transfiere por **gRPC** con el cliente de escritorio y publica
/// una cara REST de consulta, que es la que media el bus. Desde el teléfono se
/// **observa** el estado y se **resuelven conflictos**; empujar bloques es cosa
/// del cliente de escritorio.
class SyncController extends ChangeNotifier with AsyncState {
  SyncController(this._api) {
    load();
  }

  final Api _api;

  SyncState? state;
  List<Map<String, dynamic>> conflictos = const [];

  List<SyncItem> get items => state?.items ?? const [];
  bool get hayConflictos => conflictos.isNotEmpty;

  Future<void> load() => run(() async {
        final j = await _api.sync.estado();
        state = SyncState.fromApi(j);
        conflictos = (j['conflictos'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });

  /// Resuelve un conflicto de versión.
  ///
  /// [estrategia] es `local`, `servidor` o `ambos`: quedarse con lo del
  /// dispositivo, con lo del servidor, o conservar las dos copias.
  Future<void> resolver(String conflictoId, String estrategia) async {
    await _api.sync.resolver(conflictoId, estrategia);
    await load();
  }
}
