import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

enum ServiceHealth { ok, warn, error }

extension ServiceHealthColor on ServiceHealth {
  Color get color => switch (this) {
        ServiceHealth.ok => const Color(0xFF34A853),
        ServiceHealth.warn => const Color(0xFFFBBC04),
        ServiceHealth.error => const Color(0xFFEA4335),
      };
}

ServiceHealth serviceHealthFromApi(String? s) => switch (s) {
      'operativo' => ServiceHealth.ok,
      'degradado' || 'mantenimiento' => ServiceHealth.warn,
      _ => ServiceHealth.error,
    };

class ServiceStatusEntry {
  const ServiceStatusEntry({
    required this.name,
    required this.status,
    required this.responseTime,
    required this.checkedAt,
  });

  final String name;
  final ServiceHealth status;
  final String responseTime;
  final String checkedAt;

  factory ServiceStatusEntry.fromApi(Map<String, dynamic> j) => ServiceStatusEntry(
        name: j['nombre'] as String? ?? j['codigo'] as String? ?? '',
        status: serviceHealthFromApi(j['estado'] as String?),
        responseTime: '${j['tiempoRespuestaMs'] ?? 0} ms',
        checkedAt: relativeSpanish(j['ultimaVerificacion'] as String?),
      );
}

class MetricCardData {
  const MetricCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.data,
  });

  final String label;
  final String value;
  final Color color;
  final List<double> data;
}

/// Resumen completo de `GET /monitoreo`.
class MonitoringSummary {
  const MonitoringSummary({
    required this.cards,
    required this.services,
    required this.nodosDisponibles,
    required this.nodosTotal,
    required this.trabajosEjecutando,
    required this.trabajosCola,
  });

  final List<MetricCardData> cards;
  final List<ServiceStatusEntry> services;
  final int nodosDisponibles;
  final int nodosTotal;
  final int trabajosEjecutando;
  final int trabajosCola;

  factory MonitoringSummary.fromApi(Map<String, dynamic> j) {
    final r = Map<String, dynamic>.from(j['recursos'] as Map? ?? {});
    final n = Map<String, dynamic>.from(j['nodos'] as Map? ?? {});
    final t = Map<String, dynamic>.from(j['trabajos'] as Map? ?? {});
    final g = Map<String, dynamic>.from(j['graficas'] as Map? ?? {});
    List<double> serie(String k) =>
        (g[k] as List? ?? []).map((p) => ((p as Map)['valor'] as num).toDouble()).toList();

    return MonitoringSummary(
      cards: [
        MetricCardData(label: 'CPU', value: '${r['cpuPct'] ?? 0}%', color: const Color(0xFF1A73E8), data: serie('cpu')),
        MetricCardData(label: 'Memoria', value: '${r['memoriaPct'] ?? 0}%', color: const Color(0xFF9C27B0), data: serie('memoria')),
        MetricCardData(label: 'Almacenamiento', value: '${r['almacenamientoPct'] ?? 0}%', color: const Color(0xFF34A853), data: serie('cargaTrabajos')),
        MetricCardData(label: 'Trabajos', value: '${t['ejecutando'] ?? 0}', color: const Color(0xFFFBBC04), data: serie('tiempoEjecucionProm')),
      ],
      services: (j['servicios'] as List? ?? [])
          .map((e) => ServiceStatusEntry.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nodosDisponibles: (n['disponibles'] as num?)?.toInt() ?? 0,
      nodosTotal: (n['total'] as num?)?.toInt() ?? 0,
      trabajosEjecutando: (t['ejecutando'] as num?)?.toInt() ?? 0,
      trabajosCola: (t['cola'] as num?)?.toInt() ?? 0,
    );
  }
}
