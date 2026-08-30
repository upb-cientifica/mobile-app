import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/hpc_jobs_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/hpc_job.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

class _SummaryChip {
  const _SummaryChip(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

/// Lista de trabajos HPC/MPI, equivalente a screens/HPCJobsScreen.tsx.
class HpcJobsScreen extends StatelessWidget {
  const HpcJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => HpcJobsController(ctx.read<AuthController>().api),
      child: const _HpcJobsView(),
    );
  }
}

class _HpcJobsView extends StatelessWidget {
  const _HpcJobsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HpcJobsController>();
    final nav = context.read<NavigationController>();
    final summary = [
      _SummaryChip('Ejecutando', controller.ejecutando, AppColors.blue),
      _SummaryChip('En cola', controller.enCola, AppColors.warningDark),
      _SummaryChip('Completados', controller.completados, AppColors.success),
      _SummaryChip('Fallidos', controller.fallidos, AppColors.error),
    ];

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in summary)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.round)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusDot(color: s.color),
                          const SizedBox(width: 6),
                          Text(s.label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                          const SizedBox(width: 4),
                          Text('${s.count}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        UnderlineTabs(options: hpcJobFilters, selected: controller.filter, onSelected: controller.setFilter),
        Expanded(
          child: AsyncView(
            loading: controller.loading,
            error: controller.error,
            loadedOnce: controller.loadedOnce,
            onRetry: controller.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.filteredJobs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Sin trabajos', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                for (final job in controller.filteredJobs) ...[
                  _JobCard(
                    job: job,
                    onTap: () => nav.navigate(AppScreen.jobDetail, arg: job.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final HpcJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = hpcStatusStyles[job.status]!;
    final showProgress = job.status == HpcJobStatus.running || job.status == HpcJobStatus.failed;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
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
                    Text(job.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(job.id, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: monoFontFamily)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: style.label, color: style.color, background: style.bg),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.memory, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${job.language} · ${job.processes} proc.', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(job.elapsed, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(job.user, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progreso', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text('${job.progress}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: style.color)),
              ],
            ),
            const SizedBox(height: 4),
            ThinProgressBar(value: job.progress / 100, color: style.color, height: 5),
          ],
          const SizedBox(height: 8),
          Text('Enviado: ${job.sentAt}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
