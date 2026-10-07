import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/photo_models.dart';

/// Presentación de los resultados actuales, con reproducción automática.
class SlideshowScreen extends StatefulWidget {
  const SlideshowScreen({super.key, required this.fotos});
  final List<Photo> fotos;
  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> {
  final _paginas = PageController();
  Timer? _reloj;
  int _indice = 0;
  bool _controles = true;
  bool _reproduciendo = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _iniciarReloj();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precargar();
  }

  void _iniciarReloj() {
    _reloj?.cancel();
    if (_reproduciendo) {
      _reloj = Timer.periodic(const Duration(seconds: 5), (_) => _avanzar(1));
    }
  }

  void _avanzar(int paso) {
    if (widget.fotos.length < 2 || !_paginas.hasClients) return;
    _paginas.animateToPage(
      (_indice + paso) % widget.fotos.length,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _precargar() {
    if (widget.fotos.length < 2) return;
    final siguiente = widget.fotos[(_indice + 1) % widget.fotos.length];
    if (siguiente.url.isNotEmpty) {
      precacheImage(NetworkImage(siguiente.url), context, onError: (_, _) {});
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _paginas.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _controles = !_controles;
      }),
      child: Stack(
        children: [
          PageView.builder(
            controller: _paginas,
            itemCount: widget.fotos.length,
            onPageChanged: (indice) {
              setState(() {
                _indice = indice;
              });
              _precargar();
              _iniciarReloj();
            },
            itemBuilder: (context, indice) => Image.network(
              widget.fotos[indice].url,
              fit: BoxFit.contain,
              loadingBuilder: (_, imagen, progreso) => progreso == null
                  ? imagen
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, _, _) => Center(
                child: Material(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No se pudo cargar la imagen ${indice + 1}.'),
                  ),
                ),
              ),
            ),
          ),
          if (_controles)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.fotos.isEmpty
                              ? 'Sin fotografías'
                              : '${widget.fotos[_indice].title} · ${_indice + 1} / ${widget.fotos.length}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Anterior',
                              onPressed: () => _avanzar(-1),
                              icon: const Icon(Icons.skip_previous),
                            ),
                            IconButton(
                              tooltip: _reproduciendo ? 'Pausar' : 'Reproducir',
                              onPressed: () {
                                setState(() {
                                  _reproduciendo = !_reproduciendo;
                                });
                                _iniciarReloj();
                              },
                              icon: Icon(
                                _reproduciendo ? Icons.pause : Icons.play_arrow,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Siguiente',
                              onPressed: () => _avanzar(1),
                              icon: const Icon(Icons.skip_next),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
