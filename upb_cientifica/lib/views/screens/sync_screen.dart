import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/network_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (ctx) => SyncController(ctx.read<NetworkController>()),
    child: const _SyncView(),
  );
}

class _SyncView extends StatelessWidget {
  const _SyncView();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<SyncController>();
    final red = context.watch<NetworkController>();
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            backgroundColor: Theme.of(context).cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusDot(
                      color: red.enRedInterna
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      red.enRedInterna
                          ? 'En la red de la UPB'
                          : 'Fuera de la red',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (red.ocupado) const LinearProgressIndicator(),
                if (red.resumen != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Última pasada: ${red.resumen}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  for (final fallo in red.resumen!.fallos)
                    Text(
                      fallo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Guardar en este teléfono una copia de todo',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: !red.motor.sinCopiaLocal,
                  onChanged: red.ocupado || c.loading ? null : c.preferencia,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: red.ocupado || c.loading ? null : c.agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar archivos'),
              ),
              ElevatedButton.icon(
                onPressed: red.ocupado ? null : red.sincronizar,
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar ahora'),
              ),
            ],
          ),
          if (c.error != null)
            Text(c.error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 20),
          const SectionLabel('Mi unidad › Sincronizados'),
          const SizedBox(height: 10),
          if (c.archivos.isEmpty)
            const Text('No hay archivos en este teléfono.'),
          for (final ruta in c.archivos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                backgroundColor: Theme.of(context).cardColor,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(ruta, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const SectionLabel('Conflictos'),
          const SizedBox(height: 10),
          if (c.conflictos.isEmpty) const Text('Sin conflictos registrados.'),
          for (final k in c.conflictos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                backgroundColor: Theme.of(context).cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${k['ruta'] ?? k['nombre']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Resolución: ${k['resuelto'] == true ? k['estrategia'] ?? 'Resuelto' : 'Pendiente'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (k['resuelto'] != true &&
                        (k['resolucion'] == null ||
                            k['resolucion'] == '' ||
                            k['resolucion'] == 'PENDIENTE'))
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final opcion in const [
                            ('Dispositivo', 'local'),
                            ('Servidor', 'servidor'),
                            ('Ambos', 'ambos'),
                          ])
                            OutlinedButton(
                              onPressed: red.ocupado || !red.enRedInterna
                                  ? null
                                  : () => c.resolver(k, opcion.$2),
                              child: Text(opcion.$1),
                            ),
                        ],
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
