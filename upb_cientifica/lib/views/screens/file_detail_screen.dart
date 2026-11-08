import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/file_detail_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../widgets/async_view.dart';
import '../widgets/logo_mark.dart';

/// Detalle y uso compartido de un archivo del Home, con sus permisos Unix.
///
/// Todo lo de esta pantalla sale del Shared File Server a través del bus: el
/// dueño, el grupo, los tres tríos rwx, con quién está compartido y el
/// historial de versiones.
class FileDetailScreen extends StatelessWidget {
  const FileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ruta = context.read<NavigationController>().argString ?? '/';
    return ChangeNotifierProvider(
      create: (ctx) => FileDetailController(ctx.read<AuthController>().api, ruta),
      child: const _FileDetailView(),
    );
  }
}

class _FileDetailView extends StatelessWidget {
  const _FileDetailView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FileDetailController>();
    final u = context.watch<AuthController>().user;

    // El servicio decide de verdad; esto sólo evita ofrecer lo que se rechazaría.
    if (u != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.establecerUsuario(u.correo, esAdmin: u.esAdmin);
      });
    }

    return AsyncView(
      loading: c.loading,
      error: c.error,
      loadedOnce: c.loadedOnce,
      onRetry: c.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Cabecera(c: c),
          _Acceso(c: c),
          _Versiones(c: c),
          _PermisosUnix(c: c),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: !c.puedeEditar || !c.hayCambios
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await c.guardarPermisos();
                        messenger.showSnackBar(
                            SnackBar(content: Text('Permisos guardados: ${c.octal}')));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(c.puedeEditar
                  ? (c.hayCambios ? 'Guardar permisos (${c.octalPropuesto})' : 'Sin cambios')
                  : 'Sólo el propietario puede cambiarlos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.c});

  final FileDetailController c;

  static const Map<String, (IconData, Color)> _iconos = {
    'codigo': (Icons.code, AppColors.blue),
    'dataset': (Icons.storage, AppColors.success),
    'imagen': (Icons.image_outlined, AppColors.warning),
    'video': (Icons.videocam_outlined, AppColors.error),
    'documento': (Icons.description_outlined, AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final (icono, color) = _iconos[c.tipo] ?? (Icons.insert_drive_file_outlined, AppColors.textSecondary);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icono, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nombre,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${_tipoLegible(c.tipo)} · ${formatBytes(c.tamanoBytes)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(c.carpeta,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: monoFontFamily)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4.2,
            children: [
              _MetaField('Propietario', c.propietario.split('@').first),
              _MetaField('Grupo', c.grupo.isEmpty ? '—' : c.grupo),
              _MetaField('Modificado', relativeSpanish(c.modificadoEn)),
              _MetaField('Versión', c.version == 0 ? '—' : 'v.${c.version}'),
            ],
          ),
        ],
      ),
    );
  }

  static String _tipoLegible(String t) => switch (t) {
        'codigo' => 'Código',
        'dataset' => 'Dataset',
        'imagen' => 'Imagen',
        'video' => 'Video',
        'documento' => 'Documento',
        'carpeta' => 'Carpeta',
        'enlace' => 'Enlace',
        _ => 'Archivo',
      };
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.c});

  final FileDetailController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Acceso',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (c.puedeEditar)
                TextButton.icon(
                  onPressed: () => _abrirCompartir(context, c),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 14),
                  label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Persona(correo: c.propietario, papel: 'Propietario'),
          for (final s in c.compartidoCon)
            _Persona(
              correo: '${s['correo']}',
              papel: '${s['permiso']}' == 'escritura' ? 'Escritura' : 'Lectura',
              onQuitar: c.puedeEditar ? () => c.dejarDeCompartir('${s['correo']}') : null,
            ),
          if (c.compartidoCon.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('No lo has compartido con nadie',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _Persona extends StatelessWidget {
  const _Persona({required this.correo, required this.papel, this.onQuitar});

  final String correo;
  final String papel;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final nombre = correo.split('@').first;
    final partes = nombre.split(RegExp(r'[._]'));
    final iniciales = (partes.length >= 2
            ? '${partes[0][0]}${partes[1][0]}'
            : (nombre.isEmpty ? '?' : nombre.substring(0, 1)))
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          UserAvatar(size: 36, initials: iniciales),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Text(papel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (onQuitar != null)
            IconButton(
              onPressed: onQuitar,
              icon: const Icon(Icons.close, size: 16, color: AppColors.error),
              tooltip: 'Dejar de compartir',
            ),
        ],
      ),
    );
  }
}

class _Versiones extends StatelessWidget {
  const _Versiones({required this.c});

  final FileDetailController c;

  @override
  Widget build(BuildContext context) {
    if (c.versiones.isEmpty) return const SizedBox.shrink();
    // Las más recientes primero, que es como interesa leerlas.
    final vs = c.versiones.reversed.take(5).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Versiones',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          for (final v in vs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('v.${v['version']} · ${'${v['autor'] ?? ''}'.split('@').first}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  ),
                  Text(relativeSpanish('${v['fecha'] ?? ''}'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PermisosUnix extends StatelessWidget {
  const _PermisosUnix({required this.c});

  final FileDetailController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Permisos Unix',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(c.octal,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: monoFontFamily)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(
                          child: Text('Rol',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      _PermHeaderCell('R'),
                      _PermHeaderCell('W'),
                      _PermHeaderCell('X'),
                    ],
                  ),
                ),
                for (var i = 0; i < FileDetailController.roles.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: i < FileDetailController.roles.length - 1
                        ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(FileDetailController.roles[i],
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                        for (var j = 0; j < 3; j++)
                          SizedBox(
                            width: 48,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => c.alternar(i, j),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.permisos[i][j]
                                        ? (c.puedeEditar ? AppColors.blue : AppColors.textMuted)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: c.permisos[i][j]
                                          ? (c.puedeEditar ? AppColors.blue : AppColors.textMuted)
                                          : AppColors.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: c.permisos[i][j]
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide un correo y un nivel de acceso, y comparte el archivo.
Future<void> _abrirCompartir(BuildContext context, FileDetailController c) {
  final correo = TextEditingController();
  var permiso = 'lectura';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (hoja) => StatefulBuilder(
      builder: (hoja2, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(hoja2).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compartir ${c.nombre}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'correo@upb.edu.co',
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (etiqueta, valor) in const [('Lectura', 'lectura'), ('Escritura', 'escritura')]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() => permiso = valor),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: permiso == valor ? AppColors.blueLight : null,
                        side: BorderSide(color: permiso == valor ? AppColors.blue : AppColors.border),
                      ),
                      child: Text(etiqueta),
                    ),
                  ),
                  if (valor == 'lectura') const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final texto = correo.text.trim();
                if (texto.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(hoja).pop();
                try {
                  await c.compartir(texto, permiso);
                  messenger.showSnackBar(SnackBar(content: Text('Compartido con $texto')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Compartir'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaField extends StatelessWidget {
  const _MetaField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _PermHeaderCell extends StatelessWidget {
  const _PermHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}
