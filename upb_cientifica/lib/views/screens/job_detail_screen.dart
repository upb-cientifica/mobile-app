import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/job_detail_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

/// Detalle de un trabajo HPC, conectado a `GET /hpc/trabajos/:id` del BFF.
class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobId = context.read<NavigationController>().argString ?? '';
    return ChangeNotifierProvider(
      create: (ctx) => JobDetailController(ctx.read<AuthController>().api, jobId),
      child: const _JobDetailView(),
    );
  }
}

class _JobDetailView extends StatelessWidget {
  const _JobDetailView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<JobDetailController>();
    final j = controller.job;
    final progreso = ((j['progreso'] as num?) ?? 0).toInt();
    final restante = (j['metricas'] as Map?)?['tiempoRestanteMin'];

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.blue,
          padding: const EdgeInsets.all(16),
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
                        Text('${j['id'] ?? ''}'.substring(0, ('${j['id'] ?? ''}'.length).clamp(0, 8)),
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: monoFontFamily)),
                        const SizedBox(height: 4),
                        Text('${j['nombre'] ?? 'Trabajo'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  StatusPill(label: '${j['estado'] ?? '—'}', color: AppColors.blue, background: Colors.white),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progreso: $progreso%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  if (restante != null)
                    Text('~$restante min restantes', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progreso / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF69F0AE)),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: const [
                  _StatTile(Icons.memory, 'CPU utilizada', '74%', AppColors.blue),
                  _StatTile(Icons.storage, 'Memoria', '87.3 / 128 GB', AppColors.purple),
                  _StatTile(Icons.dns_outlined, 'Nodo asignado', 'compute-01', AppColors.success),
                  _StatTile(Icons.access_time, 'Tiempo transcurrido', '2h 18m', AppColors.warning),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _MiniField('Procesos MPI', '64'),
                  SizedBox(width: 16),
                  _MiniField('Inicio', '30 jul, 09:14'),
                  SizedBox(width: 16),
                  _MiniField('Usuario', 'S. García'),
                ],
              ),
            ],
          ),
        ),
        UnderlineTabs(options: JobDetailController.tabs, selected: controller.tab, onSelected: controller.setTab),
        Expanded(
          child: AsyncView(
            loading: controller.loading,
            error: controller.error,
            loadedOnce: controller.loadedOnce,
            onRetry: controller.load,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _TabContent(tab: controller.tab),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await controller.cancel();
                    messenger.showSnackBar(const SnackBar(content: Text('Cancelación solicitada')));
                  },
                  icon: const Icon(Icons.close, size: 14, color: AppColors.error),
                  label: const Text('Cancelar', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), side: const BorderSide(color: AppColors.error, width: 1.5), textStyle: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await controller.rerun();
                    messenger.showSnackBar(const SnackBar(content: Text('Re-ejecución enviada al clúster')));
                  },
                  icon: const Icon(Icons.replay, size: 14),
                  label: const Text('Re-ejecutar'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, color: color, size: 36, iconSize: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<JobDetailController>();
    Widget consola(List<String> lineas, {String vacio = 'Sin salida'}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lineas.isEmpty
                ? [Text(vacio, style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: monoFontFamily))]
                : [
                    for (final line in lineas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(line,
                            style: const TextStyle(fontSize: 11, height: 1.6, fontFamily: monoFontFamily, color: Colors.white70)),
                      ),
                  ],
          ),
        );

    switch (tab) {
      case 'Registro':
        return consola(
          c.eventos.map((e) => '${e['tipo'] ?? ''} · ${e['mensaje'] ?? ''}').toList(),
          vacio: 'Sin eventos registrados',
        );
      case 'Salida':
        return consola(c.salida);
      case 'Errores':
        return c.errores.isEmpty
            ? const AppCard(
                child: Center(child: Text('✓ Sin errores registrados', style: TextStyle(fontSize: 13, color: AppColors.success))),
              )
            : consola(c.errores);
      case 'Resultados':
        if (c.resultados.isEmpty) {
          return const AppCard(child: Center(child: Text('Aún no hay resultados', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))));
        }
        return Column(
          children: [
            for (final f in c.resultados) ...[
              AppCard(
                radius: AppRadius.md,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('${f['nombre']}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: monoFontFamily))),
                    const Icon(Icons.download_outlined, size: 16, color: AppColors.blue),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      default:
        const metrics = [
          ['Eficiencia paralela', '92.3%', 0.923, AppColors.success],
          ['Uso CPU promedio', '74%', 0.74, AppColors.blue],
          ['Uso memoria pico', '68.2%', 0.682, AppColors.purple],
          ['I/O throughput', '2.1 GB/s', 0.6, AppColors.warning],
        ];
        return AppCard(
          child: Column(
            children: [
              for (final m in metrics) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m[0] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(m[1] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m[3] as Color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ThinProgressBar(value: m[2] as double, color: m[3] as Color, height: 6),
                  ],
                ),
                if (m != metrics.last) const SizedBox(height: 14),
              ],
            ],
          ),
        );
    }
  }
}
