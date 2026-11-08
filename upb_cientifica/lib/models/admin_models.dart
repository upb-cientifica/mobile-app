import 'package:flutter/material.dart';

class AdminUserEntry {
  const AdminUserEntry({
    required this.name,
    required this.role,
    required this.active,
    required this.initials,
    required this.color,
  });

  final String name;
  final String role;
  final bool active;
  final String initials;
  final Color color;

  factory AdminUserEntry.fromApi(Map<String, dynamic> j, int index) {
    const palette = [Color(0xFF1A73E8), Color(0xFF34A853), Color(0xFF9C27B0), Color(0xFFFBBC04), Color(0xFF00897B)];
    final nombre = j['nombre'] as String? ?? (j['correo'] as String? ?? '');
    final parts = nombre.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?');
    return AdminUserEntry(
      name: nombre,
      role: (j['rol'] as String? ?? '').isEmpty
          ? 'Usuario'
          : '${(j['rol'] as String)[0].toUpperCase()}${(j['rol'] as String).substring(1)}',
      active: (j['estado'] as String? ?? 'activo') == 'activo',
      initials: initials,
      color: palette[index % palette.length],
    );
  }
}

class AdminOptionEntry {
  const AdminOptionEntry({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
}

const List<AdminOptionEntry> adminOptions = [
  AdminOptionEntry(icon: Icons.groups_outlined, label: 'Gestión de usuarios', sub: 'Consultar y editar cuentas', color: Color(0xFF1A73E8)),
  AdminOptionEntry(icon: Icons.shield_outlined, label: 'Roles y permisos', sub: 'admin · investigador · estudiante · operador', color: Color(0xFF9C27B0)),
  AdminOptionEntry(icon: Icons.sd_storage_outlined, label: 'Cuotas de almacenamiento', sub: 'Por usuario', color: Color(0xFF34A853)),
  AdminOptionEntry(icon: Icons.dns_outlined, label: 'Servicios del clúster', sub: 'Estado y disponibilidad', color: Color(0xFFFBBC04)),
  AdminOptionEntry(icon: Icons.notifications_none, label: 'Alertas del sistema', sub: 'Revisar alertas activas', color: Color(0xFFEA4335)),
  AdminOptionEntry(icon: Icons.description_outlined, label: 'Registro de auditoría', sub: 'Eventos recientes', color: Color(0xFF5F6368)),
  AdminOptionEntry(icon: Icons.hub_outlined, label: 'Mapa de servicios', sub: 'Visualizar topología', color: Color(0xFF00897B)),
];

class SecurityOptionEntry {
  const SecurityOptionEntry({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;
}

const List<SecurityOptionEntry> securityOptions = [
  SecurityOptionEntry(icon: Icons.vpn_key_outlined, label: 'Cambiar contraseña'),
  SecurityOptionEntry(icon: Icons.shield_outlined, label: 'Autenticación de dos factores'),
  SecurityOptionEntry(icon: Icons.vpn_key_outlined, label: 'Administrar tokens API'),
  SecurityOptionEntry(icon: Icons.desktop_windows_outlined, label: 'Sesiones activas'),
  SecurityOptionEntry(icon: Icons.logout, label: 'Cerrar sesión en otros dispositivos', color: Color(0xFFFBBC04)),
  SecurityOptionEntry(icon: Icons.shield_outlined, label: 'Actividad de seguridad'),
];
