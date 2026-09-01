import 'package:flutter/material.dart';

import '../core/utils/date_utils.dart';

class FolderEntry {
  const FolderEntry({
    required this.id,
    required this.name,
    required this.path,
    this.fileCount = 0,
    this.modified = '',
  });

  final String id;
  final String name;
  final String path;
  final int fileCount;
  final String modified;

  factory FolderEntry.fromApi(Map<String, dynamic> j) => FolderEntry(
        id: '${j['id']}',
        name: j['nombre'] as String? ?? '',
        path: j['ruta'] as String? ?? '/',
        modified: relativeSpanish(j['modificadoEn'] as String?),
      );
}

class FileEntry {
  const FileEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.date,
    required this.owner,
    required this.synced,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String type;
  final String size;
  final String date;
  final String owner;
  final bool synced;
  final IconData icon;
  final Color color;

  factory FileEntry.fromApi(Map<String, dynamic> j) {
    final tipo = (j['tipo'] as String? ?? 'otro');
    final (String label, IconData icon, Color color) = switch (tipo) {
      'codigo' => ('Código', Icons.code, const Color(0xFF1A73E8)),
      'dataset' => ('Dataset', Icons.storage, const Color(0xFF34A853)),
      'imagen' => ('Imagen', Icons.image_outlined, const Color(0xFFFBBC04)),
      'video' => ('Video', Icons.videocam_outlined, const Color(0xFFEA4335)),
      'documento' => ('Documento', Icons.description_outlined, const Color(0xFF5F6368)),
      _ => ('Archivo', Icons.insert_drive_file_outlined, const Color(0xFF5F6368)),
    };
    return FileEntry(
      id: '${j['id']}',
      name: j['nombre'] as String? ?? '',
      type: label,
      size: formatBytes((j['tamanoBytes'] as num?) ?? 0),
      date: relativeSpanish(j['modificadoEn'] as String?),
      owner: (j['propietario'] as String? ?? '').split('@').first,
      synced: (j['estadoSync'] as String?) == 'sincronizado',
      icon: icon,
      color: color,
    );
  }
}

const List<String> fileFilters = [
  'Todos',
  'Documentos',
  'Imágenes',
  'Videos',
  'Código',
  'Datasets',
];

/// Etiqueta del filtro de la interfaz -> tipo que clasifica el Home compartido.
String? fileFilterToApi(String f) => switch (f) {
      'Documentos' => 'documentos',
      'Imágenes' => 'imagenes',
      'Videos' => 'videos',
      'Código' => 'codigo',
      'Datasets' => 'datasets',
      _ => null,
    };

const List<String> fileMenuActions = [
  'Abrir',
  'Descargar',
  'Compartir',
  'Renombrar',
  'Mover',
  'Versiones',
  'Permisos',
  'Eliminar',
];
