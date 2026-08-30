import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Muestra spinner / error / contenido según el estado de un controlador
/// que usa el mixin `AsyncState`.
class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.loading,
    required this.error,
    required this.loadedOnce,
    required this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool loadedOnce;
  final Future<void> Function() onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading && !loadedOnce) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null && !loadedOnce) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: onRetry, child: child);
  }
}
