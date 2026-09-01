import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/files_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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
                  TextButton.icon(
                    onPressed: () => _pickAndUpload(context, controller),
                    icon: const Icon(Icons.upload_file, size: 16, color: AppColors.blue),
                    label: const Text('Subir', style: TextStyle(fontSize: 12, color: AppColors.blue)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                    _FolderTile(folder: folder, onTap: () => controller.openFolder(folder)),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 10),
                ],
                const SectionLabel('Archivos'),
                const SizedBox(height: 8),
                if (controller.files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('Carpeta vacía', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else if (controller.viewMode == FilesViewMode.list)
                  for (final file in controller.files) ...[
                    _FileListTile(file: file, onTap: () => nav.navigate(AppScreen.fileDetail, arg: file.id)),
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
                        _FileGridTile(file: file, onTap: () => nav.navigate(AppScreen.fileDetail, arg: file.id)),
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

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.onTap});

  final FolderEntry folder;
  final VoidCallback onTap;

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
          const Icon(Icons.chevron_right, size: 16, color: AppColors.border),
        ],
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({required this.file, required this.onTap});

  final FileEntry file;
  final VoidCallback onTap;

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              for (final action in fileMenuActions)
                PopupMenuItem(
                  value: action,
                  child: Text(action, style: TextStyle(fontSize: 13, color: action == 'Eliminar' ? AppColors.error : AppColors.textPrimary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileGridTile extends StatelessWidget {
  const _FileGridTile({required this.file, required this.onTap});

  final FileEntry file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: file.icon, color: file.color, size: 38),
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
