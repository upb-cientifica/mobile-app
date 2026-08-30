import 'package:flutter/material.dart';

enum SyncStatus { synced, pending, conflict, error, syncing, offline }

class SyncStatusStyle {
  const SyncStatusStyle({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;
}

const Map<SyncStatus, SyncStatusStyle> syncStatusStyles = {
  SyncStatus.synced: SyncStatusStyle(label: 'Sincronizado', color: Color(0xFF34A853), bg: Color(0xFFE6F4EA)),
  SyncStatus.pending: SyncStatusStyle(label: 'Pendiente', color: Color(0xFFFBBC04), bg: Color(0xFFFEF9E7)),
  SyncStatus.conflict: SyncStatusStyle(label: 'Conflicto', color: Color(0xFFEA4335), bg: Color(0xFFFDE8E7)),
  SyncStatus.error: SyncStatusStyle(label: 'Error', color: Color(0xFFEA4335), bg: Color(0xFFFDE8E7)),
  SyncStatus.syncing: SyncStatusStyle(label: 'Sincronizando…', color: Color(0xFF1A73E8), bg: Color(0xFFE8F0FE)),
  SyncStatus.offline: SyncStatusStyle(label: 'Sin conexión', color: Color(0xFF5F6368), bg: Color(0xFFF8F9FA)),
};

SyncStatus syncStatusFromApi(String? s) => switch (s) {
      'sincronizado' => SyncStatus.synced,
      'sincronizando' => SyncStatus.syncing,
      'pendiente' => SyncStatus.pending,
      'conflicto' => SyncStatus.conflict,
      'error' => SyncStatus.error,
      _ => SyncStatus.offline,
    };

class SyncItem {
  const SyncItem({required this.name, required this.status, this.detail = ''});

  final String name;
  final SyncStatus status;
  final String detail;

  factory SyncItem.fromApi(Map<String, dynamic> j) => SyncItem(
        name: j['nombre'] as String? ?? '',
        status: syncStatusFromApi(j['estado'] as String?),
        detail: [
          if (j['carpetaLocal'] != null) j['carpetaLocal'],
          if ((j['pendientes'] as num?) != null && (j['pendientes'] as num) > 0)
            '${j['pendientes']} pendientes',
        ].join(' · '),
      );
}

/// Resumen de sincronización devuelto por `GET /sync`.
class SyncState {
  const SyncState({
    required this.estadoGeneral,
    required this.pendientesTotal,
    required this.items,
    required this.conflictos,
  });

  final SyncStatus estadoGeneral;
  final int pendientesTotal;
  final List<SyncItem> items;
  final int conflictos;

  factory SyncState.fromApi(Map<String, dynamic> j) => SyncState(
        estadoGeneral: syncStatusFromApi(j['estadoGeneral'] as String?),
        pendientesTotal: (j['pendientesTotal'] as num?)?.toInt() ?? 0,
        items: (j['dispositivos'] as List? ?? [])
            .map((e) => SyncItem.fromApi(Map<String, dynamic>.from(e as Map)))
            .toList(),
        conflictos: (j['conflictos'] as List? ?? []).length,
      );
}
