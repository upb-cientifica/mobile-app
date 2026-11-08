import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/navigation/navigation_controller.dart';
import '../../core/navigation/screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/admin_models.dart';
import '../widgets/common_widgets.dart';

const _serviciosNombre = {
  'shared_file': 'Shared File',
  'file_sync': 'File Sync',
  'photo_album': 'Photo Album',
  'streaming': 'Streaming',
  'hpc': 'HPC',
  'monitoreo': 'Monitoreo',
  'api': 'API',
};

/// Perfil y seguridad del usuario, alimentado por `AuthController`.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationController>();
    final auth = context.watch<AuthController>();
    final u = auth.user;
    final iniciales = (u?.nombre ?? 'U')
        .trim()
        .split(RegExp(r'\s+'))
        .map((p) => p.isEmpty ? '' : p[0])
        .take(2)
        .join()
        .toUpperCase();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: Column(
            children: [
              _AvatarLarge(initials: iniciales),
              const SizedBox(height: 12),
              Text(u?.nombre ?? 'Usuario',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(u?.correo ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  _ProfileTag(_capitalizar(u?.rol ?? 'usuario')),
                  if (u?.grupo != null) _ProfileTag(u!.grupo!),
                ],
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              radius: AppRadius.xl,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Servicios autorizados'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in (u?.servicios ?? const <String>[]))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(AppRadius.round)),
                          child: Text(_serviciosNombre[s] ?? s,
                              style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),
                  if (u?.homePath != null) ...[
                    const SizedBox(height: 12),
                    Text('Home: ${u!.homePath}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: monoFontFamily)),
                  ],
                  const SizedBox(height: 8),
                  // El uso real lo lleva el Home compartido, que es quien
                  // guarda los archivos; el contador del directorio no se
                  // actualiza con cada subida y mostraría 0 siempre.
                  FutureBuilder<Map<String, dynamic>>(
                    future: context.read<AuthController>().api.archivos.home(),
                    builder: (context, snap) {
                      final home = snap.data;
                      final usado = (home?['usadoBytes'] as num?)?.toInt() ?? u?.usoBytes ?? 0;
                      final cuota = (home?['cuotaBytes'] as num?)?.toInt() ?? u?.cuotaBytes ?? 0;
                      return Text('Cuota: ${formatBytes(usado)} / ${formatBytes(cuota)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AppCard(
            radius: AppRadius.lg,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < securityOptions.length; i++)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: i < securityOptions.length - 1
                        ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                        : null,
                    child: Row(
                      children: [
                        Icon(securityOptions[i].icon, size: 18, color: securityOptions[i].color ?? AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(securityOptions[i].label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                        const Icon(Icons.chevron_right, size: 14, color: AppColors.border),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(AppRadius.md)),
            // Decía "Copias de seguridad protegidas mediante cifrado GPG". El
            // cifrado de las copias está en el plan del proyecto pero todavía no
            // existe, y anunciarlo aquí le da al usuario una garantía falsa
            // sobre sus datos. Se enuncia lo que el sistema sí hace hoy.
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Cada servicio verifica tu token firmado por separado',
                      style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
        if (u?.esAdmin ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ElevatedButton(
              onPressed: () => nav.navigate(AppScreen.admin),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.textPrimary),
              child: const Text('Administración del sistema →'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthController>().logout(),
            icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
            label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

String _capitalizar(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _AvatarLarge extends StatelessWidget {
  const _AvatarLarge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
      ),
      child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
    );
  }
}
