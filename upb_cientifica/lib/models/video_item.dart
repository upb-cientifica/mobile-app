import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.project,
    required this.author,
    required this.duration,
    required this.access,
    required this.date,
    required this.color,
    required this.emoji,
  });

  final String id;
  final String title;
  final String project;
  final String author;
  final String duration;
  final String access;
  final String date;
  final Color color;
  final String emoji;

  factory VideoItem.fromApi(Map<String, dynamic> j, int index) {
    const swatches = [Color(0xFFE8F0FE), Color(0xFFE6F4EA), Color(0xFFF3E5F5), Color(0xFFFDE8E7)];
    const emojis = ['🧬', '🌍', '💻', '🔬'];
    return VideoItem(
      id: '${j['id']}',
      title: j['titulo'] as String? ?? '',
      project: j['proyecto'] as String? ?? 'General',
      author: j['autor'] as String? ?? '',
      duration: formatDuration((j['duracionSeg'] as num?)?.toInt() ?? 0),
      access: switch (j['nivelAcceso']) {
        'publico' => 'Público',
        'privado' => 'Restringido',
        _ => 'Grupo',
      },
      date: relativeSpanish(j['publicadoEn'] as String?),
      color: swatches[index % swatches.length],
      emoji: emojis[index % emojis.length],
    );
  }
}
