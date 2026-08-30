import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.time,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String time;
  final String sub;

  /// Construye desde `actividadReciente` del endpoint `/dashboard`.
  factory ActivityItem.fromApi(Map<String, dynamic> j) {
    final tipo = (j['tipo'] as String? ?? '').toLowerCase();
    final (IconData icon, Color color) = switch (tipo) {
      'subida' => (Icons.upload_outlined, const Color(0xFF34A853)),
      'trabajo' => (Icons.memory, const Color(0xFF1A73E8)),
      'compartido' => (Icons.share_outlined, const Color(0xFF9C27B0)),
      'sync' => (Icons.sync, const Color(0xFF00897B)),
      _ => (Icons.notifications_none, const Color(0xFFFBBC04)),
    };
    return ActivityItem(
      icon: icon,
      color: color,
      label: j['titulo'] as String? ?? '',
      sub: j['detalle'] as String? ?? '',
      time: relativeSpanish(j['fecha'] as String?),
    );
  }
}

class QuickLinkData {
  const QuickLinkData({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
}
