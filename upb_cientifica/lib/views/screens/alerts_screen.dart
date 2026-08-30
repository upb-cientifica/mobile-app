import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/alerts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert_item.dart';
import '../widgets/async_view.dart';
import '../widgets/common_widgets.dart';

/// Centro de alertas y notificaciones, equivalente a
/// screens/AlertsScreen.tsx.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AlertsController(ctx.read<AuthController>().api),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AlertsController>();

    return Column(
      children: [
        if (controller.unreadCount > 0)
          Container(
            width: double.infinity,
            color: AppColors.blueLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${controller.unreadCount} notificaciones sin leer', style: const TextStyle(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w500)),
                TextButton(
                  onPressed: controller.markAllRead,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('Marcar todas leídas', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        UnderlineTabs(options: alertFilters, selected: controller.filter, onSelected: controller.setFilter),
        Expanded(
          child: AsyncView(
            loading: controller.loading,
            error: controller.error,
            loadedOnce: controller.loadedOnce,
            onRetry: controller.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.filteredAlerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Sin alertas', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                for (final alert in controller.filteredAlerts) ...[
                  GestureDetector(
                    onTap: alert.read ? null : () => controller.markRead(alert.id),
                    child: _AlertTile(alert: alert),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: alert.read ? AppColors.white : const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: cardShadow,
        border: alert.read ? null : Border(left: BorderSide(color: alert.color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: alert.icon, color: alert.color, background: alert.bg, size: 36, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(fontSize: 13, fontWeight: alert.read ? FontWeight.w400 : FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    if (!alert.read) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: StatusDot(color: alert.color)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(alert.sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(alert.time, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
