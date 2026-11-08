import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/create_job_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

const List<String> _stepLabels = ['Información', 'Programa', 'Recursos', 'Confirmación'];

/// Formulario de envío de un trabajo al clúster, en 4 pasos. El último encola
/// el trabajo llamando por el bus al objeto remoto `ClusterHpc` (Java RMI).
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
        const SizedBox(height: 8),
        const Text(
          'Es el nombre con el que aparecerá en la cola del clúster y en la '
          'consola del equipo.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// El programa a ejecutar y de dónde tomarlo.
///
/// El clúster corre el comando con `mpirun` dentro de la carpeta indicada del
/// Home, que es donde ya viven el código y los datos: no hay que volver a
/// subirlos desde el teléfono.
class _StepFiles extends StatelessWidget {
  const _StepFiles();

  @override
  Widget build(BuildContext context) {
    final c = context.read<CreateJobController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Programa a ejecutar'),
        const _FormLabel('Comando'),
        TextField(
          controller: c.comando,
          style: const TextStyle(fontFamily: monoFontFamily, fontSize: 13),
          decoration: const InputDecoration(
            hintText: './simulacion.out --iteraciones 1000',
            filled: true,
            fillColor: AppColors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'El ejecutable con sus argumentos, tal como se lo pasarías a mpirun.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        const _FormLabel('Carpeta del repositorio'),
        TextField(
          controller: c.rutaHome,
          style: const TextStyle(fontFamily: monoFontFamily, fontSize: 13),
          decoration: const InputDecoration(
            hintText: '/proyectos/clima',
            filled: true,
            fillColor: AppColors.white,
            prefixIcon: Icon(Icons.folder_open_outlined, size: 18, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Carpeta de tu Home con el código y los datos. El clúster los toma de '
          'ahí y deja los resultados en el mismo sitio.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StepConfig extends StatelessWidget {
  const _StepConfig();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateJobController>();
    final slots = c.slotsDisponibles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle('Recursos'),
        const _FormLabel('Procesos MPI'),
        Row(
          children: [
            IconButton.outlined(
              onPressed: c.procesos > 1 ? () => c.setProcesos(c.procesos - 1) : null,
              icon: const Icon(Icons.remove, size: 18),
            ),
            Expanded(
              child: Text(
                '${c.procesos}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            IconButton.outlined(
              onPressed: () => c.setProcesos(c.procesos + 1),
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: slots == null
                ? AppColors.white
                : (c.procesos > slots ? AppColors.warningLight : AppColors.blueLight),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                slots == null ? Icons.help_outline : (c.procesos > slots ? Icons.schedule : Icons.check),
                size: 16,
                color: slots == null
                    ? AppColors.textMuted
                    : (c.procesos > slots ? AppColors.warning : AppColors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (slots) {
                    null => 'No se pudo consultar la disponibilidad del clúster.',
                    _ when c.procesos > slots =>
                      'Hay $slots ranuras libres: el trabajo esperará en cola hasta que se liberen.',
                    _ => 'Hay $slots ranuras libres: el trabajo puede arrancar de inmediato.',
                  },
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'El planificador reparte por ranuras de nodo: no se piden núcleos, '
          'memoria ni tiempo máximo por separado.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StepConfirm extends StatelessWidget {
  const _StepConfirm();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateJobController>();
    final resumen = [
      ['Nombre', c.nombre.text.trim()],
      ['Comando', c.comando.text.trim()],
      ['Carpeta', c.rutaHome.text.trim()],
      ['Procesos MPI', '${c.procesos}'],
    ];
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
              const SectionLabel('Se enviará al clúster'),
              const SizedBox(height: 10),
              for (var i = 0; i < resumen.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < resumen.length - 1 ? 8 : 0),
                  child: Container(
                    padding: EdgeInsets.only(bottom: i < resumen.length - 1 ? 8 : 0),
                    decoration: i < resumen.length - 1
                        ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(resumen[i][0], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            resumen[i][1].isEmpty ? '—' : resumen[i][1],
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                          ),
                        ),
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
          decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Row(
            children: [
              Icon(Icons.hub_outlined, size: 16, color: AppColors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El trabajo entra por el bus de servicios, que lo traduce a una '
                  'invocación Java RMI sobre el clúster.',
                  style: TextStyle(fontSize: 12, color: AppColors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
