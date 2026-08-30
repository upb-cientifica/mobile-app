import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/streaming_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../widgets/async_view.dart';

/// Biblioteca de streaming científico, conectada a `GET /streaming/videos`.
class StreamingScreen extends StatelessWidget {
  const StreamingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => StreamingController(ctx.read<AuthController>().api),
      child: const _StreamingView(),
    );
  }
}

class _StreamingView extends StatelessWidget {
  const _StreamingView();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationController>();
    final c = context.watch<StreamingController>();
    final featured = c.videos.isNotEmpty ? c.videos.first : null;

    return AsyncView(
      loading: c.loading,
      error: c.error,
      loadedOnce: c.loadedOnce,
      onRetry: c.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          if (featured != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: () => nav.navigate(AppScreen.videoPlayer, arg: featured.id),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.blueDark, AppColors.blue]),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DESTACADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(featured.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3)),
                            const SizedBox(height: 4),
                            Text('${featured.author} · ${featured.duration}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text(featured.emoji, style: const TextStyle(fontSize: 48))),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Biblioteca científica', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          for (final video in c.videos) ...[
            _VideoTile(video: video, onTap: () => nav.navigate(AppScreen.videoPlayer, arg: video.id)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(boxShadow: cardShadow),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                color: video.color,
                alignment: Alignment.center,
                child: Text(video.emoji, style: const TextStyle(fontSize: 28)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('${video.author} · ${video.project}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 10, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(video.duration, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          const Icon(Icons.lock_outline, size: 10, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(video.access, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
