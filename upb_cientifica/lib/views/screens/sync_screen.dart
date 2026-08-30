import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/network_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/sync_item.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

/// Centro de sincronización, conectado a `GET/POST /sync` del BFF.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SyncController(ctx.read<AuthController>().api),
      child: const _SyncView(),
    );
  }
}

class _SyncView extends StatelessWidget {
  const _SyncView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    final net = context.watch<NetworkController>();
    final st = c.state;
    final estilo = st == null ? null : syncStatusStyles[st.estadoGeneral]!;

    return AsyncView(
      loading: c.loading,
      error: c.error,
      loadedOnce: c.loadedOnce,
      onRetry: c.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusDot(color: estilo?.color ?? AppColors.textMuted, size: 10),
                    const SizedBox(width: 8),
                    Text(estilo?.label ?? 'Sincronización',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const Spacer(),
                    Icon(net.onWifi ? Icons.wifi : Icons.wifi_off,
                        size: 18, color: net.onWifi ? AppColors.success : AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  net.lastAutoSync != null
                      ? 'Auto-sync Wi-Fi: ${relativeSpanish(net.lastAutoSync!.toIso8601String())}'
                      : (st != null && st.pendientesTotal > 0
                          ? '${st.pendientesTotal} archivo(s) pendiente(s)'
                          : 'Todo al día'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (st != null && st.conflictos > 0) ...[
                  const SizedBox(height: 8),
                  Text('${st.conflictos} conflicto(s) de versión por resolver',
                      style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: c.loading ? null : c.syncNow,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Sincronizar ahora'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: c.loading ? null : c.pause,
                    icon: const Icon(Icons.pause, size: 14),
                    label: const Text('Pausar'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Dispositivos y carpetas'),
                const SizedBox(height: 10),
                if (c.items.isEmpty)
                  const Text('Sin dispositivos vinculados', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                else
                  for (final item in c.items) ...[
                    _SyncTile(item: item),
                    const SizedBox(height: 6),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.item});

  final SyncItem item;

  @override
  Widget build(BuildContext context) {
    final style = syncStatusStyles[item.status]!;
    final isProblem = item.status == SyncStatus.conflict || item.status == SyncStatus.error;

    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(isProblem ? Icons.warning_amber_outlined : Icons.devices, size: 18, color: style.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                if (item.detail.isNotEmpty)
                  Text(item.detail, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          StatusPill(label: style.label, color: style.color, background: style.bg),
        ],
      ),
    );
  }
}
