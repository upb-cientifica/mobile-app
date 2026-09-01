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
    required this.program,
    required this.processes,
    required this.sentAt,
    required this.elapsed,
    required this.status,
    required this.progress,
    required this.user,
    this.command = '',
  });

  final String id;
  final String name;

  /// Ejecutable que corre el trabajo. El clúster recibe un comando para
  /// `mpirun`, no un "lenguaje" declarado: lo que identifica la carga es el
  /// programa que se está ejecutando.
  final String program;
  final int processes;
  final String sentAt;

  /// Tiempo transcurrido. El planificador no estima cuánto falta —depende del
  /// programa—, así que se muestra lo que sí se sabe.
  final String elapsed;
  final HpcJobStatus status;
  final int progress;
  final String user;

  /// Comando completo, para el detalle del trabajo.
  final String command;

  factory HpcJob.fromApi(Map<String, dynamic> j) => HpcJob(
        id: '${j['id']}',
        name: j['nombre'] as String? ?? '',
        program: j['programa'] as String? ?? '—',
        processes: (j['procesos'] as num?)?.toInt() ?? 0,
        sentAt: relativeSpanish(j['creadoEn'] as String?),
        elapsed: _duracion((j['duracionSeg'] as num?)?.toInt() ?? 0),
        status: hpcStatusFromApi(j['estado'] as String?),
        progress: (j['progreso'] as num?)?.toInt() ?? 0,
        user: (j['propietario'] as String? ?? '').split('@').first,
        command: j['comando'] as String? ?? '',
      );

  static String _duracion(int seg) {
    if (seg <= 0) return '—';
    if (seg < 60) return '$seg s';
    if (seg < 3600) return '${seg ~/ 60} min';
    return '${(seg / 3600).toStringAsFixed(1)} h';
  }
}

const List<String> hpcJobFilters = ['Todos', 'En cola', 'Ejecutando', 'Completados', 'Fallidos'];

String hpcFilterToApi(String f) => switch (f) {
      'En cola' => 'cola',
      'Ejecutando' => 'ejecutando',
      'Completados' => 'completados',
      'Fallidos' => 'fallidos',
      _ => 'todos',
    };
