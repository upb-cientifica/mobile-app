import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/photo_album_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/photo_models.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

/// Álbum de fotos, conectado a `GET /fotos` del BFF.
class PhotoAlbumScreen extends StatelessWidget {
  const PhotoAlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PhotoAlbumController(ctx.read<AuthController>().api),
      child: const _PhotoAlbumView(),
    );
  }
}

class _PhotoAlbumView extends StatelessWidget {
  const _PhotoAlbumView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotoAlbumController>();

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.round)),
            child: const Row(
              children: [
                Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Buscar imágenes…', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        UnderlineTabs(options: photoTabs, selected: controller.tab, onSelected: controller.setTab),
        Expanded(
          child: AsyncView(
            loading: controller.loading,
            error: controller.error,
            loadedOnce: controller.loadedOnce,
            onRetry: controller.load,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: controller.tab == 'Álbumes' ? const _AlbumsGrid() : const _PhotosGrid(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mis álbumes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 12),
              label: const Text('Crear', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.round)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: [
            for (final album in context.watch<PhotoAlbumController>().albums)
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: cardShadow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 80,
                      width: double.infinity,
                      color: album.color,
                      alignment: Alignment.center,
                      child: const Text('🔬', style: TextStyle(fontSize: 28)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(album.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${album.count} fotos', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recientes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, padding: EdgeInsets.zero, minimumSize: Size.zero),
              child: const Text('Ordenar por fecha ↓', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final photos = context.watch<PhotoAlbumController>().photos;
          if (photos.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Sin fotografías', style: TextStyle(color: AppColors.textSecondary))),
            );
          }
          return GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: [
              for (final photo in photos)
                Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: photo.swatch, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    if (photo.favorite)
                      const Positioned(
                        top: 4, right: 4,
                        child: Icon(Icons.favorite, size: 14, color: AppColors.error),
                      ),
                  ],
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.share_outlined, size: 14),
          label: const Text('Compartir selección'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
