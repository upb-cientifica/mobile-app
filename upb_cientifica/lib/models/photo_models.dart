import 'package:flutter/material.dart';

class PhotoAlbum {
  const PhotoAlbum({required this.id, required this.name, required this.count, required this.color});

  final String id;
  final String name;
  final int count;
  final Color color;

  factory PhotoAlbum.fromApi(Map<String, dynamic> j, int index) => PhotoAlbum(
        id: '${j['id']}',
        name: j['nombre'] as String? ?? '',
        count: (j['fotos'] as num?)?.toInt() ?? 0,
        color: _albumBg[index % _albumBg.length],
      );
}

const List<Color> _albumBg = [
  Color(0xFFE8F0FE),
  Color(0xFFE6F4EA),
  Color(0xFFFEF9E7),
  Color(0xFFF3E5F5),
];

class Photo {
  const Photo({
    required this.id,
    required this.title,
    required this.swatch,
    this.thumbnailUrl = '',
    this.url = '',
    this.favorite = false,
    this.tags = const [],
  });

  final String id;
  final String title;

  /// Miniatura y original, servidas por el Álbum de fotos a través del bus.
  final String thumbnailUrl;
  final String url;

  /// Color de relleno mientras la miniatura carga, y si no llegara a cargar.
  final Color swatch;
  final bool favorite;
  final List<String> tags;

  factory Photo.fromApi(Map<String, dynamic> j, int index) => Photo(
        id: '${j['id']}',
        title: j['titulo'] as String? ?? '',
        thumbnailUrl: j['miniatura'] as String? ?? '',
        url: j['url'] as String? ?? '',
        favorite: j['favorito'] == true,
        tags: (j['etiquetas'] as List? ?? []).map((e) => '$e').toList(),
        swatch: photoSwatches[index % photoSwatches.length],
      );
}

const List<String> photoTabs = ['Álbumes', 'Recientes', 'Proyectos', 'Favoritos', 'Compartidos'];

/// Colores de relleno mientras carga cada miniatura, y respaldo si no llega.
const List<Color> photoSwatches = [
  Color(0xFFB8CFF3),
  Color(0xFFA8D8B9),
  Color(0xFFF6D488),
  Color(0xFFE8B4C8),
  Color(0xFFC9B8E8),
  Color(0xFF9AD0D6),
  Color(0xFFE0A6A0),
  Color(0xFFB3C7E6),
  Color(0xFFCDE0A3),
];
