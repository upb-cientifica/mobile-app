import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/create_job_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

const List<String> _stepLabels = ['Información', 'Archivos', 'Configuración', 'Confirmación'];

/// Formulario de creación de un trabajo HPC en 4 pasos. En el último paso
/// envía el trabajo al clúster vía `POST /hpc/trabajos` del BFF.
class CreateJobScreen extends StatelessWidget {
  const CreateJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CreateJobController(ctx.read<AuthController>().api),
      child: const _CreateJobView(),
    );
  }
}

class _CreateJobView extends StatelessWidget {
  const _CreateJobView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CreateJobController>();
    final nav = context.read<NavigationController>();

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              for (var i = 0; i < _stepLabels.length; i++) ...[
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < controller.step
                            ? AppColors.success
                            : i == controller.step
                                ? AppColors.blue
                                : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: i < controller.step
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i <= controller.step ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepLabels[i],
                      style: TextStyle(fontSize: 9, color: i == controller.step ? AppColors.blue : AppColors.textMuted),
                    ),
                  ],
                ),
                if (i < _stepLabels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                      color: i < controller.step ? AppColors.success : AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: switch (controller.step) {
              0 => const _StepInfo(),
              1 => const _StepFiles(),
              2 => const _StepConfig(),
              _ => const _StepConfirm(),
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (controller.step > 0) ...[
                Expanded(
                  child: OutlinedButton(onPressed: controller.back, child: const Text('Anterior')),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: controller.submitting
                      ? null
                      : () async {
                          final shouldSubmit = controller.next();
                          if (!shouldSubmit) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await controller.submit();
                          messenger.showSnackBar(SnackBar(
                            content: Text(ok
                                ? 'Trabajo enviado al clúster'
                                : (controller.error ?? 'No se pudo enviar')),
                          ));
                          if (ok) {
                            controller.reset();
                            nav.navigate(AppScreen.hpc);
                          }
                        },
                  child: controller.submitting
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(controller.isLastStep ? 'Enviar al clúster' : 'Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    );
  }
}

class _StepInfo extends StatelessWidget {
  const _StepInfo();

  @override
  Widget build(BuildContext context) {
    final c = context.read<CreateJobController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Información del trabajo'),
        const _FormLabel('Nombre del trabajo'),
        TextField(
          controller: c.nombre,
          decoration: const InputDecoration(hintText: 'ej. Simulación Monte Carlo v3', filled: true, fillColor: AppColors.white),
        ),
        const SizedBox(height: 14),
        const _FormLabel('Descripción'),
        TextField(
          controller: c.descripcion,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Describe el objetivo científico…', filled: true, fillColor: AppColors.white),
        ),
        const SizedBox(height: 14),
        const _FormLabel('Proyecto relacionado'),
        TextField(
          controller: c.proyecto,
          decoration: const InputDecoration(hintText: 'ej. clima, genomica…', filled: true, fillColor: AppColors.white),
        ),
      ],
    );
  }
}

class _FileOption {
  const _FileOption(this.icon, this.label, this.sub, this.color, this.bg, this.selected);

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final Color bg;
  final bool selected;
}

class _StepFiles extends StatelessWidget {
  const _StepFiles();

  static const List<_FileOption> _items = [
    _FileOption(Icons.upload_outlined, 'Cargar código fuente', 'Arrastra o selecciona .py, .cpp, .f90…', AppColors.blue, AppColors.blueLight, false),
    _FileOption(Icons.storage, 'Conjunto de datos', 'datos_sensores.csv (2.4 MB)', AppColors.success, AppColors.successLight, true),
    _FileOption(Icons.folder_open_outlined, 'Archivos del repositorio', '3 archivos seleccionados', AppColors.purple, AppColors.purpleLight, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Archivos del trabajo'),
        for (final item in _items) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: item.selected ? item.color : AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: item.bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(item.icon, size: 20, color: item.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (item.selected) Icon(Icons.check, size: 16, color: item.color),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _StepConfig extends StatelessWidget {
  const _StepConfig();

  static const List<List<String>> _fields = [
    ['Lenguaje', 'Python 3.11'],
    ['Procesos MPI', '64'],
    ['Núcleos por proceso', '4'],
    ['Memoria (GB)', '128'],
    ['Tiempo máximo (h)', '12'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Configuración de recursos'),
        for (final f in _fields) ...[
          _FormLabel(f[0]),
          TextField(controller: TextEditingController(text: f[1]), decoration: const InputDecoration(filled: true, fillColor: AppColors.white)),
          const SizedBox(height: 14),
        ],
        const _FormLabel('Prioridad'),
        Row(
          children: [
            for (final p in ['Baja', 'Normal', 'Alta']) ...[
              Expanded(
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == 'Normal' ? AppColors.blueLight : AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: p == 'Normal' ? AppColors.blue : AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontSize: 13,
                      color: p == 'Normal' ? AppColors.blue : AppColors.textSecondary,
                      fontWeight: p == 'Normal' ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (p != 'Alta') const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepConfirm extends StatelessWidget {
  const _StepConfirm();

  static const List<List<String>> _summary = [
    ['Nombre', 'Simulación Monte Carlo v3'],
    ['Lenguaje', 'Python 3.11'],
    ['Procesos MPI', '64'],
    ['Núcleos totales', '256'],
    ['Memoria', '128 GB'],
    ['Tiempo máximo', '12 horas'],
    ['Prioridad', 'Normal'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Confirmación'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: cardShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Recursos solicitados'),
              const SizedBox(height: 10),
              for (var i = 0; i < _summary.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < _summary.length - 1 ? 8 : 0),
                  child: Container(
                    padding: EdgeInsets.only(bottom: i < _summary.length - 1 ? 8 : 0),
                    decoration: i < _summary.length - 1
                        ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_summary[i][0], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(_summary[i][1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Row(
            children: [
              Icon(Icons.check, size: 16, color: AppColors.success),
              SizedBox(width: 8),
              Text('Código validado correctamente', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
