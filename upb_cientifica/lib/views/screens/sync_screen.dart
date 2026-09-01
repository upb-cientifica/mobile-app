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

/// Centro de sincronización, sobre la cara REST del servicio de File Sync.
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
                  child: OutlinedButton.icon(
                    onPressed: c.loading ? null : c.load,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: c.loading || !c.hayConflictos
                        ? null
                        : () => _abrirConflictos(context, c),
                    icon: const Icon(Icons.merge_type, size: 14),
                    label: Text(c.hayConflictos ? 'Resolver (${c.conflictos.length})' : 'Sin conflictos'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
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

/// Hoja de resolución de conflictos.
///
/// Es la única escritura que la cara REST del servicio expone, y la que hace
/// útil llevar la sincronización en el bolsillo: el conflicto se decide donde
/// esté la persona, no donde esté su portátil.
Future<void> _abrirConflictos(BuildContext context, SyncController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Conflictos de versión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'El mismo archivo cambió en dos sitios a la vez. Elige con cuál quedarte.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final k in c.conflictos) ...[
            AppCard(
              radius: AppRadius.md,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${k['nombre'] ?? k['ruta']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${k['dispositivo']} · versión del servidor ${k['versionServidor']}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (etiqueta, estrategia) in const [
                        ('Dispositivo', 'local'),
                        ('Servidor', 'servidor'),
                        ('Ambos', 'ambos'),
                      ]) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(sheetCtx).pop();
                              try {
                                await c.resolver('${k['id']}', estrategia);
                                messenger.showSnackBar(
                                    const SnackBar(content: Text('Conflicto resuelto')));
                              } catch (e) {
                                messenger.showSnackBar(SnackBar(content: Text('$e')));
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text(etiqueta),
                          ),
                        ),
                        if (estrategia != 'ambos') const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
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
