import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/photo_album_controller.dart';
import '../../data/api_exception.dart';
import '../../data/servicios/fotos.dart';
import '../../models/photo_models.dart';
import '../widgets/async_view.dart';
import 'album_share_sheet.dart';
import 'slideshow_screen.dart';

/// Álbum de fotos, conectado al servicio de Álbum a través del bus.
class PhotoAlbumScreen extends StatelessWidget {
  const PhotoAlbumScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (ctx) => PhotoAlbumController(ctx.read<AuthController>().api),
    child: const _PhotoAlbumView(),
  );
}

class _PhotoAlbumView extends StatelessWidget {
  const _PhotoAlbumView();
  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<PhotoAlbumController>();
    final album = controlador.albumSeleccionado;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: controlador.buscar,
            decoration: const InputDecoration(
              hintText: 'Buscar imágenes…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: controlador.albumId == null,
                onSelected: (_) => controlador.seleccionarAlbum(null),
              ),
              for (final album in controlador.albums)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text('${album.name} (${album.count})'),
                    selected: controlador.albumId == album.id,
                    onSelected: (_) => controlador.seleccionarAlbum(album.id),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: controlador.etiqueta ?? '',
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todas las etiquetas'),
                    ),
                    for (final etiqueta in {
                      ...controlador.etiquetas,
                      if (controlador.etiqueta != null) controlador.etiqueta!,
                    })
                      DropdownMenuItem(value: etiqueta, child: Text(etiqueta)),
                  ],
                  onChanged: (valor) => controlador.seleccionarEtiqueta(
                    valor == '' ? null : valor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Favoritos'),
                selected: controlador.tab == 'Favoritos',
                onSelected: (valor) =>
                    controlador.setTab(valor ? 'Favoritos' : 'Recientes'),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (album != null && album.puedeCompartir)
              TextButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartir álbum'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      AlbumShareSheet(album: album, controller: controlador),
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.slideshow),
              label: const Text('Presentación'),
              onPressed: controlador.photos.isEmpty || controlador.loading
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SlideshowScreen(fotos: List.of(controlador.photos)),
                      ),
                    ),
            ),
          ],
        ),
        Expanded(
          child: AsyncView(
            loading: controlador.loading,
            error: controlador.error,
            loadedOnce: controlador.loadedOnce,
            onRetry: controlador.load,
            child: controlador.photos.isEmpty
                ? const Center(child: Text('Sin fotografías'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          mainAxisExtent: 270,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: controlador.photos.length,
                    itemBuilder: (context, indice) {
                      final foto = controlador.photos[indice];
                      void editar() => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            _EditarFoto(foto: foto, controlador: controlador),
                      );
                      return Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onLongPress: editar,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Image.network(
                                  foto.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, imagen, progreso) =>
                                      progreso == null
                                      ? imagen
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  if (foto.favorite)
                                    Icon(
                                      Icons.favorite,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  Expanded(
                                    child: Text(
                                      foto.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opciones de imagen',
                                    onSelected: (_) => editar(),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar detalles'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 44,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      for (final etiqueta in foto.tags)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Chip(label: Text(etiqueta)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _EditarFoto extends StatefulWidget {
  const _EditarFoto({required this.foto, required this.controlador});
  final Photo foto;
  final PhotoAlbumController controlador;
  @override
  State<_EditarFoto> createState() => _EditarFotoState();
}

class _EditarFotoState extends State<_EditarFoto> {
  late final _titulo = TextEditingController(text: widget.foto.title);
  late final _descripcion = TextEditingController(
    text: widget.foto.descripcion,
  );
  final _entrada = TextEditingController();
  late List<String> _etiquetas = analizarEtiquetas(widget.foto.tags.join(','));
  bool _guardando = false;
  String? _error;

  void _agregar({bool completo = true}) {
    final texto = _entrada.text;
    final corte = completo ? texto.length : texto.lastIndexOf(',');
    if (corte < 0) return;
    setState(() {
      _etiquetas = analizarEtiquetas(
        [..._etiquetas, texto.substring(0, corte)].join(','),
      );
      _entrada.text = completo ? '' : texto.substring(corte + 1);
      _entrada.selection = TextSelection.collapsed(
        offset: _entrada.text.length,
      );
    });
  }

  Future<void> _guardar() async {
    _agregar();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.controlador.actualizar(
        widget.foto,
        _titulo.text.trim(),
        _descripcion.text.trim(),
        _etiquetas,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.mensaje
              : 'No se pudieron guardar los detalles.';
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

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Editar detalles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titulo,
            enabled: !_guardando,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcion,
            enabled: !_guardando,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final etiqueta in _etiquetas)
                InputChip(
                  label: Text(etiqueta),
                  onDeleted: _guardando
                      ? null
                      : () => setState(() {
                          _etiquetas.remove(etiqueta);
                        }),
                ),
            ],
          ),
          TextField(
            controller: _entrada,
            enabled: !_guardando,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Etiquetas',
              hintText: 'Escribe y pulsa listo o coma',
            ),
            onChanged: (_) => _agregar(completo: false),
            onSubmitted: (_) => _agregar(),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}
