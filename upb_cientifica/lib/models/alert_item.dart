import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

class AlertItem {
  const AlertItem({
    required this.id,
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.sub,
    required this.time,
    required this.type,
    required this.read,
  });

  final String id;
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String sub;
  final String time;
  final String type;
  final bool read;

  factory AlertItem.fromApi(Map<String, dynamic> j) {
    final categoria = (j['categoria'] as String? ?? 'sistema');
    final severidad = (j['severidad'] as String? ?? 'info');
    final (IconData icon, Color color, Color bg) = switch (severidad) {
      'critica' => (Icons.error_outline, const Color(0xFFEA4335), const Color(0xFFFDE8E7)),
      'advertencia' => (Icons.warning_amber_outlined, const Color(0xFFFBBC04), const Color(0xFFFEF9E7)),
      _ => (Icons.info_outline, const Color(0xFF1A73E8), const Color(0xFFE8F0FE)),
    };
    return AlertItem(
      id: '${j['id']}',
      icon: icon,
      color: color,
      bg: bg,
      title: j['titulo'] as String? ?? '',
      sub: j['mensaje'] as String? ?? '',
      time: relativeSpanish(j['creadaEn'] as String?),
      type: _tipoLabel(categoria),
      read: j['leida'] == true,
    );
  }

  static String _tipoLabel(String c) => switch (c) {
        'seguridad' => 'Seguridad',
        'archivos' => 'Archivos',
        'hpc' => 'HPC',
        'sync' => 'Sync',
        _ => 'Sistema',
      };
}

const List<String> alertFilters = ['Todos', 'Sistema', 'Seguridad', 'Archivos', 'HPC', 'Sync'];

/// Traduce la etiqueta del filtro de la interfaz a la categoría de la alerta.
String? alertFilterToCategoria(String filtro) => switch (filtro) {
      'Sistema' => 'sistema',
      'Seguridad' => 'seguridad',
      'Archivos' => 'archivos',
      'HPC' => 'hpc',
      'Sync' => 'sync',
      _ => null,
    };
