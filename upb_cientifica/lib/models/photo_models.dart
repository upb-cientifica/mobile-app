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
  const Photo({required this.id, required this.title, required this.swatch, this.favorite = false});

  final String id;
  final String title;
  final Color swatch;
  final bool favorite;

  factory Photo.fromApi(Map<String, dynamic> j, int index) => Photo(
        id: '${j['id']}',
        title: j['titulo'] as String? ?? '',
        favorite: j['favorito'] == true,
        swatch: mockPhotoSwatches[index % mockPhotoSwatches.length],
      );
}

const List<String> photoTabs = ['Álbumes', 'Recientes', 'Proyectos', 'Favoritos', 'Compartidos'];

/// Colores de relleno usados como miniaturas (evita imágenes remotas de terceros).
const List<Color> mockPhotoSwatches = [
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
