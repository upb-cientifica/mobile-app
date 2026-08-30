import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

enum HpcJobStatus { queue, running, done, failed }

class HpcStatusStyle {
  const HpcStatusStyle({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;
}

const Map<HpcJobStatus, HpcStatusStyle> hpcStatusStyles = {
  HpcJobStatus.queue: HpcStatusStyle(label: 'En cola', color: Color(0xFF856D00), bg: Color(0xFFFEF9E7)),
  HpcJobStatus.running: HpcStatusStyle(label: 'Ejecutando', color: Color(0xFF1A73E8), bg: Color(0xFFE8F0FE)),
  HpcJobStatus.done: HpcStatusStyle(label: 'Completado', color: Color(0xFF34A853), bg: Color(0xFFE6F4EA)),
  HpcJobStatus.failed: HpcStatusStyle(label: 'Fallido', color: Color(0xFFEA4335), bg: Color(0xFFFDE8E7)),
};

HpcJobStatus hpcStatusFromApi(String? s) => switch (s) {
      'ejecutando' => HpcJobStatus.running,
      'completado' => HpcJobStatus.done,
      'fallido' || 'cancelado' => HpcJobStatus.failed,
      _ => HpcJobStatus.queue,
    };

class HpcJob {
  const HpcJob({
    required this.id,
    required this.name,
    required this.language,
    required this.processes,
    required this.sentAt,
    required this.elapsed,
    required this.status,
    required this.progress,
    required this.user,
  });

  final String id;
  final String name;
  final String language;
  final int processes;
  final String sentAt;
  final String elapsed;
  final HpcJobStatus status;
  final int progress;
  final String user;

  factory HpcJob.fromApi(Map<String, dynamic> j) => HpcJob(
        id: '${j['id']}',
        name: j['nombre'] as String? ?? '',
        language: j['lenguaje'] as String? ?? 'C',
        processes: (j['procesosMpi'] as num?)?.toInt() ?? 0,
        sentAt: relativeSpanish(j['enviadoEn'] as String?),
        elapsed: j['tiempoRestanteMin'] == null
            ? '—'
            : '${j['tiempoRestanteMin']} min restantes',
        status: hpcStatusFromApi(j['estado'] as String?),
        progress: (j['progreso'] as num?)?.toInt() ?? 0,
        user: (j['usuario'] as String? ?? '').split('@').first,
      );
}

const List<String> hpcJobFilters = ['Todos', 'En cola', 'Ejecutando', 'Completados', 'Fallidos'];

String hpcFilterToApi(String f) => switch (f) {
      'En cola' => 'cola',
      'Ejecutando' => 'ejecutando',
      'Completados' => 'completados',
      'Fallidos' => 'fallidos',
      _ => 'todos',
    };
