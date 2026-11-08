import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';
import '../widgets/logo_mark.dart';

/// Vista de administrador. Usuarios vía SOAP (`/admin/usuarios`), nodos y
/// auditoría (sesiones abiertas) desde el propio directorio.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AdminController(ctx.read<AuthController>().api),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminController>();
    final nodosActivos = c.nodos.where((n) => n['estado'] == 'activo').length;

    return AsyncView(
      loading: c.loading,
      error: c.error,
      loadedOnce: c.loadedOnce,
      onRetry: c.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.textPrimary,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PANEL DE', style: TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.6)),
                const SizedBox(height: 4),
                const Text('Administración',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _badge('${c.total} usuarios', AppColors.success),
                    _badge('$nodosActivos/${c.nodos.length} nodos', AppColors.blue),
                    _badge('${c.auditoria.length} eventos', AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCard(
              radius: AppRadius.lg,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Usuarios', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < c.users.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: i < c.users.length - 1
                          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                          : null,
                      child: Row(
                        children: [
                          UserAvatar(size: 36, initials: c.users[i].initials),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.users[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                Text(c.users[i].role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: c.users[i].active ? 'activo' : 'inactivo',
                            color: c.users[i].active ? AppColors.success : AppColors.error,
                            background: c.users[i].active ? AppColors.successLight : AppColors.errorLight,
                            fontSize: 10,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCard(
              radius: AppRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nodos del clúster',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  for (final n in c.nodos) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          StatusDot(color: switch (n['estado']) {
                            'activo' => AppColors.success,
                            'mantenimiento' => AppColors.warning,
                            _ => AppColors.error,
                          }),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${n['nombre']}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                          Text('${n['slots'] ?? 0} ranuras',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: AppCard(
              radius: AppRadius.lg,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < adminOptions.length; i++)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: i < adminOptions.length - 1
                          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider)))
                          : null,
                      child: Row(
                        children: [
                          IconTile(icon: adminOptions[i].icon, color: adminOptions[i].color, size: 36, iconSize: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(adminOptions[i].label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                Text(adminOptions[i].sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 14, color: AppColors.border),
                        ],
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

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(AppRadius.round)),
        child: Text(label, style: TextStyle(fontSize: 11, color: color)),
      );
}
