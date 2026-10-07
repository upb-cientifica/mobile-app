import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/photo_album_controller.dart';
import '../../data/api_exception.dart';
import '../../data/servicios/fotos.dart';
import '../../models/photo_models.dart';

/// Permisos del álbum y enlace revocable.
class AlbumShareSheet extends StatefulWidget {
  const AlbumShareSheet({
    super.key,
    required this.album,
    required this.controller,
  });
  final PhotoAlbum album;
  final PhotoAlbumController controller;
  @override
  State<AlbumShareSheet> createState() => _AlbumShareSheetState();
}

class _AlbumShareSheetState extends State<AlbumShareSheet> {
  late PhotoAlbum _album = widget.album;
  final _correo = TextEditingController();
  bool _guardando = false;
  String? _error;

  Future<void> _ejecutar(Future<PhotoAlbum> Function() accion) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final album = await accion();
      if (mounted) {
        setState(() {
          _album = album;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.mensaje
              : 'No se pudo actualizar el álbum.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  void _anadir() {
    if (!correoInstitucionalValido(_correo.text)) {
      setState(() {
        _error = 'Introduce un correo válido de @upb.edu.co.';
      });
      return;
    }
    _ejecutar(
      () =>
          widget.controller.compartir(_album.id, _correo.text, conceder: true),
    );
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              Text(
                'Compartir álbum: ${_album.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Personas'),
                  Tab(text: 'Enlace público'),
                ],
              ),
              if (_guardando) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        for (final correo in _album.compartidoCon)
                          ListTile(
                            title: Text(correo),
                            trailing: IconButton(
                              tooltip: 'Quitar acceso',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: _guardando
                                  ? null
                                  : () => _ejecutar(
                                      () => widget.controller.compartir(
                                        _album.id,
                                        correo,
                                        conceder: false,
                                      ),
                                    ),
                            ),
                          ),
                        TextField(
                          controller: _correo,
                          enabled: !_guardando,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo institucional',
                          ),
                          onSubmitted: (_) => _anadir(),
                        ),
                        TextButton(
                          onPressed: _guardando ? null : _anadir,
                          child: const Text('Añadir'),
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        SwitchListTile(
                          title: const Text('Enlace público'),
                          value: _album.publico,
                          onChanged: _guardando
                              ? null
                              : (activo) => _ejecutar(
                                  () => widget.controller.publicar(
                                    _album.id,
                                    activo: activo,
                                  ),
                                ),
                        ),
                        const Text(
                          'Cualquiera con este enlace puede ver el álbum sin iniciar sesión. Desactívalo para revocarlo.',
                        ),
                        if (_album.publico && _album.urlPublica != null) ...[
                          const SizedBox(height: 16),
                          SelectableText(_album.urlPublica!),
                          TextButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Copiar'),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _album.urlPublica!),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enlace copiado'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
