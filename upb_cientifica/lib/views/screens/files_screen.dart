import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/files_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api_exception.dart';
import '../../models/file_models.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

/// Explorador de archivos, equivalente a screens/FilesScreen.tsx.
class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => FilesController(ctx.read<AuthController>().api),
      child: const _FilesView(),
    );
  }
}

Future<void> _pickAndUpload(BuildContext context, FilesController controller) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await FilePicker.platform.pickFiles(withData: true);
  final file = result?.files.singleOrNull;
  if (file == null || file.bytes == null) return;
  try {
    await controller.upload(file.name, file.bytes!);
    messenger.showSnackBar(SnackBar(content: Text('${file.name} subido')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo subir: $e')));
  }
}

/// Lo que el usuario debe leer de un error: el mensaje del servicio si lo hay.
String _mensajeDe(Object e) => e is ApiException ? e.mensaje : '$e'.replaceFirst('Exception: ', '');

// Guardar pasa por la memoria del teléfono (el selector del sistema recibe los
// bytes), así que lo muy grande se baja desde la web o el escritorio.
const int _maxBytesDescarga = 150 * 1024 * 1024;

Future<void> _descargar(
  BuildContext context,
  FilesController c, {
  required String ruta,
  required String nombre,
  required bool carpeta,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final guardado = carpeta ? '$nombre.zip' : nombre;
  messenger.showSnackBar(SnackBar(content: Text('Descargando $guardado…')));
  File? temporal;
  try {
    temporal = await c.downloadToTemp(ruta, guardado);
    if (await temporal.length() > _maxBytesDescarga) {
      throw Exception('$guardado es demasiado grande para guardarlo desde el celular; '
          'bájalo desde la web o la app de escritorio');
    }
    final destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar $guardado',
      fileName: guardado,
      bytes: await temporal.readAsBytes(),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(destino == null ? 'Descarga cancelada' : '$guardado guardado')));
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('No se pudo descargar: ${_mensajeDe(e)}')));
  } finally {
    if (temporal != null && await temporal.exists()) await temporal.delete();
  }
}

Future<bool> _confirmar(BuildContext context, String titulo, String mensaje, String accion) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(accion, style: const TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> _pedirNombre(BuildContext context, String inicial) {
  final texto = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nuevo nombre'),
      content: TextField(controller: texto, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, texto.text), child: const Text('Guardar')),
      ],
    ),
  );
}

/// Ejecuta [accion] y avisa del resultado; un fallo se explica, no se traga.
Future<void> _intentar(BuildContext context, Future<void> Function() accion, String exito) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await accion();
    messenger.showSnackBar(SnackBar(content: Text(exito)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo completar: ${_mensajeDe(e)}')));
  }
}

/// Acciones del menú ⋮ de un archivo o una carpeta, en cualquiera de las vistas.
Future<void> _accion(
  BuildContext context,
  FilesController c, {
  required String accion,
  required String ruta,
  required String nombre,
  required bool carpeta,
}) async {
  switch (accion) {
    case 'Abrir' || 'Compartir' || 'Versiones' || 'Permisos':
      context.read<NavigationController>().navigate(AppScreen.fileDetail, arg: ruta);
    case 'Descargar' || 'Descargar como ZIP':
      await _descargar(context, c, ruta: ruta, nombre: nombre, carpeta: carpeta);
    case 'Renombrar':
      final nuevo = await _pedirNombre(context, nombre);
      if (nuevo == null || nuevo.trim().isEmpty || nuevo.trim() == nombre || !context.mounted) return;
      await _intentar(context, () => c.rename(ruta, nuevo.trim()), 'Renombrado');
    case 'Eliminar':
      if (!await _confirmar(context, 'Mover a la papelera', '¿Mover "$nombre" a la papelera?', 'Mover') ||
          !context.mounted) {
        return;
      }
      await _intentar(context, () => c.deleteFile(ruta), '"$nombre" está en la papelera');
    case 'Restaurar':
      await _intentar(context, () => c.restore(ruta), '"$nombre" restaurado');
    case 'Eliminar definitivamente':
      if (!await _confirmar(context, 'Eliminar para siempre',
              '¿Eliminar "$nombre" para siempre? No se puede deshacer.', 'Eliminar') ||
          !context.mounted) {
        return;
      }
      await _intentar(context, () => c.deletePermanently(ruta), '"$nombre" eliminado');
  }
}

Future<void> _vaciarPapelera(BuildContext context, FilesController c) async {
  if (!await _confirmar(context, 'Vaciar la papelera',
          '¿Eliminar para siempre todo lo que hay en la papelera? No se puede deshacer.', 'Vaciar') ||
      !context.mounted) {
    return;
  }
  await _intentar(context, c.emptyTrash, 'Papelera vaciada');
}

class _FilesView extends StatelessWidget {
  const _FilesView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FilesController>();
    final nav = context.read<NavigationController>();

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < controller.breadcrumb.length; i++) ...[
                    if (i > 0) const Icon(Icons.chevron_right, size: 14, color: AppColors.textSecondary),
                    GestureDetector(
                      onTap: () => controller.goTo(i),
                      child: Text(
                        controller.breadcrumb[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: i == controller.breadcrumb.length - 1
                              ? AppColors.textPrimary
                              : AppColors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToggleIconButton(
                    icon: Icons.grid_view,
                    active: controller.viewMode == FilesViewMode.grid,
                    onTap: () => controller.setViewMode(FilesViewMode.grid),
                  ),
                  const SizedBox(width: 8),
                  _ToggleIconButton(
                    icon: Icons.view_list,
                    active: controller.viewMode == FilesViewMode.list,
                    onTap: () => controller.setViewMode(FilesViewMode.list),
                  ),
                  const Spacer(),
                  if (controller.enPapelera)
                    TextButton.icon(
                      onPressed: () => _vaciarPapelera(context, controller),
                      icon: const Icon(Icons.delete_forever, size: 16, color: AppColors.error),
                      label: const Text('Vaciar', style: TextStyle(fontSize: 12, color: AppColors.error)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _pickAndUpload(context, controller),
                      icon: const Icon(Icons.upload_file, size: 16, color: AppColors.blue),
                      label: const Text('Subir', style: TextStyle(fontSize: 12, color: AppColors.blue)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                  TextButton.icon(
                    onPressed: controller.alternarPapelera,
                    icon: Icon(controller.enPapelera ? Icons.folder_open : Icons.delete_outline,
                        size: 16, color: AppColors.blue),
                    label: Text(controller.enPapelera ? 'Mis archivos' : 'Papelera',
                        style: const TextStyle(fontSize: 12, color: AppColors.blue)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!controller.enPapelera)
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChipsRow(options: fileFilters, selected: controller.filter, onSelected: controller.setFilter),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: AsyncView(
            loading: controller.loading,
            error: controller.error,
            loadedOnce: controller.loadedOnce,
            onRetry: controller.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.folders.isNotEmpty) ...[
                  const SectionLabel('Carpetas'),
                  const SizedBox(height: 8),
                  for (final folder in controller.folders) ...[
                    _FolderTile(
                      folder: folder,
                      // En la papelera una carpeta no se abre: se restaura o se elimina.
                      onTap: controller.enPapelera ? () {} : () => controller.openFolder(folder),
                      actions: controller.enPapelera ? trashMenuActions : folderMenuActions,
                      onAction: (a) => _accion(context, controller,
                          accion: a, ruta: folder.path, nombre: folder.name, carpeta: true),
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 10),
                ],
                const SectionLabel('Archivos'),
                const SizedBox(height: 8),
                if (controller.files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(child: Text(controller.enPapelera ? 'La papelera está vacía' : 'Carpeta vacía',
                        style: const TextStyle(color: AppColors.textSecondary))),
                  )
                else if (controller.viewMode == FilesViewMode.list)
                  for (final file in controller.files) ...[
                    _FileListTile(
                      file: file,
                      onTap: controller.enPapelera ? () {} : () => nav.navigate(AppScreen.fileDetail, arg: file.id),
                      actions: controller.enPapelera ? trashMenuActions : fileMenuActions,
                      onAction: (a) => _accion(context, controller,
                          accion: a, ruta: file.id, nombre: file.name, carpeta: false),
                    ),
                    const SizedBox(height: 6),
                  ]
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                    children: [
                      for (final file in controller.files)
                        _FileGridTile(
                          file: file,
                          onTap: controller.enPapelera ? () {} : () => nav.navigate(AppScreen.fileDetail, arg: file.id),
                          actions: controller.enPapelera ? trashMenuActions : fileMenuActions,
                          onAction: (a) => _accion(context, controller,
                              accion: a, ruta: file.id, nombre: file.name, carpeta: false),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleIconButton extends StatelessWidget {
  const _ToggleIconButton({required this.icon, required this.active, required this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.blueLight : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(icon, size: 16, color: active ? AppColors.blue : AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Menú ⋮ compartido por carpetas y archivos; lo peligroso va en rojo.
class _MenuAcciones extends StatelessWidget {
  const _MenuAcciones({required this.actions, required this.onAction});

  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      onSelected: onAction,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Text(action,
                style: TextStyle(
                    fontSize: 13,
                    color: action.startsWith('Eliminar') ? AppColors.error : AppColors.textPrimary)),
          ),
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.onTap, required this.actions, required this.onAction});

  final FolderEntry folder;
  final VoidCallback onTap;
  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.folder, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(folder.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                // El servicio no cuenta los hijos de cada carpeta —lo haría
                // recorriendo el árbol entero en cada listado—, así que se
                // muestra la fecha, que sí viene con el nodo.
                Text(folder.modified.isEmpty ? 'Carpeta' : folder.modified,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          _MenuAcciones(actions: actions, onAction: onAction),
        ],
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({required this.file, required this.onTap, required this.actions, required this.onAction});

  final FileEntry file;
  final VoidCallback onTap;
  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          IconTile(icon: file.icon, color: file.color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(file.size, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    const _Dot(),
                    Text(file.date, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    const _Dot(),
                    if (file.synced)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 10, color: AppColors.success),
                          SizedBox(width: 2),
                          Text('Sincronizado', style: TextStyle(fontSize: 10, color: AppColors.success)),
                        ],
                      )
                    else
                      const Text('Pendiente', style: TextStyle(fontSize: 10, color: AppColors.warning)),
                  ],
                ),
              ],
            ),
          ),
          _MenuAcciones(actions: actions, onAction: onAction),
        ],
      ),
    );
  }
}

class _FileGridTile extends StatelessWidget {
  const _FileGridTile({required this.file, required this.onTap, required this.actions, required this.onAction});

  final FileEntry file;
  final VoidCallback onTap;
  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: file.icon, color: file.color, size: 38),
              const Spacer(),
              _MenuAcciones(actions: actions, onAction: onAction),
            ],
          ),
          const Spacer(),
          Text(file.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(file.size, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(fontSize: 10, color: AppColors.border)),
    );
  }
}
