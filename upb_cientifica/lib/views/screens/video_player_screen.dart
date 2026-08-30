import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/video_player_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/theme/app_colors.dart';

/// Reproductor de video científico. Usa el paquete `video_player` sobre la URL
/// (HLS) que entrega `GET /streaming/videos/:id/manifest` del BFF.
class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final videoId = context.read<NavigationController>().argString;
    return ChangeNotifierProvider(
      create: (ctx) =>
          VideoPlaybackController(ctx.read<AuthController>().api, videoId: videoId)..init(),
      child: const _VideoPlayerView(),
    );
  }
}

class _VideoPlayerView extends StatelessWidget {
  const _VideoPlayerView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VideoPlaybackController>();

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              onTap: c.togglePlay,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D1B2A), Color(0xFF1A3A6E)],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  if (c.player != null && c.player!.value.isInitialized)
                    VideoPlayer(c.player!),
                  if (c.loading)
                    const CircularProgressIndicator(color: Colors.white),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        c.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  if (!c.loading && c.error == null && !c.playing)
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    ),
                ],
              ),
            ),
          ),
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Slider(
                  value: c.progress.clamp(0.0, 1.0),
                  onChanged: c.seekTo,
                  activeColor: AppColors.blue,
                  inactiveColor: const Color(0xFF333333),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => c.skip(-0.1),
                      icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                      child: IconButton(
                        onPressed: c.togglePlay,
                        icon: Icon(c.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => c.skip(0.1),
                      icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: ColoredBox(
              color: Color(0xFF1A1A1A),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Reproducción servida por el servicio de Streaming del CCA.\n'
                    'El control de acceso se aplica en el BFF con el token de sesión.',
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
