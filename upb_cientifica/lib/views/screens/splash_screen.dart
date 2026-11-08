import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pantalla de bienvenida. Se muestra mientras `AuthController` comprueba si
/// hay una sesión guardada; en cuanto termina, `_Root` navega solo.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(painter: _NetworkPainter()),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cloud, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'UPB Científica',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60),
                  child: Text(
                    'Computación distribuida para la investigación',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 64),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(active: true),
                    const SizedBox(width: 6),
                    _Dot(active: false),
                    const SizedBox(width: 6),
                    _Dot(active: false),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'Centro de Computación Avanzada · UPB',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.blue : AppColors.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Dibuja una malla de nodos y conexiones, similar al SVG conceptual del
/// boceto de Figma, escalada al tamaño real de la pantalla.
class _NetworkPainter extends CustomPainter {
  static const List<List<double>> _nodes = [
    [60, 100], [120, 200], [180, 100], [240, 200], [300, 100],
    [60, 300], [180, 300], [300, 300],
    [120, 400], [240, 400],
    [60, 500], [180, 500], [300, 500],
    [120, 600], [240, 600],
  ];

  static const List<List<double>> _edges = [
    [60, 100, 120, 200], [120, 200, 180, 100], [180, 100, 240, 200], [240, 200, 300, 100],
    [60, 300, 120, 200], [60, 300, 180, 300], [180, 300, 240, 200], [180, 300, 300, 300],
    [60, 300, 60, 500], [180, 300, 180, 500], [120, 400, 120, 200], [240, 400, 240, 200],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    final sy = size.height / 744;
    final linePaint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 1;
    final edgePaint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 1.5;
    final dotPaint = Paint()..color = AppColors.blue;

    for (final x in [60.0, 120.0, 180.0, 240.0, 300.0]) {
      canvas.drawLine(Offset(x * sx, 0), Offset(x * sx, size.height), linePaint);
    }
    for (final y in [100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 700.0]) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), linePaint);
    }
    for (final e in _edges) {
      canvas.drawLine(Offset(e[0] * sx, e[1] * sy), Offset(e[2] * sx, e[3] * sy), edgePaint);
    }
    for (final n in _nodes) {
      canvas.drawCircle(Offset(n[0] * sx, n[1] * sy), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) => false;
}
