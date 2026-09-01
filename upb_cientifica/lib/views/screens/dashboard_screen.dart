import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/network_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/activity_item.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

class _QuickLink {
  const _QuickLink(this.icon, this.label, this.color, this.bg, this.screen);

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final AppScreen screen;
}

const List<_QuickLink> _quickLinks = [
  _QuickLink(Icons.share_outlined, 'Compartidos', AppColors.blue, AppColors.blueLight, AppScreen.files),
  _QuickLink(Icons.refresh, 'Sincronización', AppColors.success, AppColors.successLight, AppScreen.sync),
  _QuickLink(Icons.image_outlined, 'Álbum', AppColors.warning, AppColors.warningLight, AppScreen.photos),
  _QuickLink(Icons.play_circle_outline, 'Streaming', AppColors.error, AppColors.errorLight, AppScreen.streaming),
  _QuickLink(Icons.memory, 'HPC', AppColors.purple, AppColors.purpleLight, AppScreen.hpc),
];

/// Pantalla principal. Resume cuatro servicios a la vez; la agregación la
/// hace la app, que entra por el bus como cualquier otro consumidor.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardController(
        ctx.read<AuthController>().api,
        nombreUsuario: ctx.read<AuthController>().user?.nombre ?? '',
      ),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DashboardController>();
    final nav = context.read<NavigationController>();
    final pct = (c.cuotaBytes == 0 ? 0.0 : c.usadoBytes / c.cuotaBytes).clamp(0.0, 1.0);

    return AsyncView(
      loading: c.loading,
      error: c.error,
      loadedOnce: c.loadedOnce,
      onRetry: c.load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatSpanishLongDate(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(c.saludo,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Almacenamiento',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              c.almacenamientoTexto.isEmpty
                                  ? '${formatBytes(c.usadoBytes)} de ${formatBytes(c.cuotaBytes)}'
                                  : c.almacenamientoTexto,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusRow(
                            label: c.syncEstado == 'sincronizado' ? 'Sincronizado' : 'Sync pendiente',
                            ok: c.syncEstado == 'sincronizado',
                          ),
                          const SizedBox(height: 4),
                          // El estado de la red lo sabe el observador de
                          // conectividad, no ningún servicio del sistema.
                          Builder(builder: (ctx) {
                            final enWifi = ctx.watch<NetworkController>().onWifi;
                            return _StatusRow(
                              label: enWifi ? 'Red UPB activa' : 'Fuera de red UPB',
                              ok: enWifi,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ThinProgressBar(value: pct.toDouble(), color: pct > 0.8 ? AppColors.warning : AppColors.blue),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${c.archivos} archivos', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('${c.porcentaje}% utilizado', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Acceso rápido',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final link in _quickLinks)
                      AppCard(
                        radius: AppRadius.lg,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        onTap: () => nav.navigate(link.screen),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconTile(icon: link.icon, color: link.color, background: link.bg, size: 40, iconSize: 20, radius: AppRadius.md),
                            const SizedBox(height: 8),
                            Text(link.label,
                                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Actividad reciente',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                if (c.actividad.isEmpty)
                  const Text('Sin actividad reciente', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                else
                  for (final item in c.actividad) ...[
                    _ActivityTile(item: item),
                    if (item != c.actividad.last) const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Clúster HPC', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text('${c.hpcEjecutando + c.hpcCola} trabajos activos',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                      const Icon(Icons.memory, color: Colors.white54, size: 32),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _HpcStat(value: '${c.hpcEjecutando}', label: 'Ejecutando', color: const Color(0xFF69F0AE)),
                      const SizedBox(width: 16),
                      _HpcStat(value: '${c.hpcCola}', label: 'En cola', color: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => nav.navigate(AppScreen.hpc),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Ver trabajos →',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, this.ok = true});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: AppRadius.md,
      child: Row(
        children: [
          IconTile(icon: item.icon, color: item.color, size: 36, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.time, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _HpcStat extends StatelessWidget {
  const _HpcStat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
