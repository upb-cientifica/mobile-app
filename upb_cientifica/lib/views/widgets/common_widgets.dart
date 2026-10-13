import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Tarjeta blanca con esquinas redondeadas y sombra sutil, el bloque base
/// del sistema de diseño de UPB Científica.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = AppRadius.lg,
    this.onTap,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Etiqueta de estado tipo "pill" (usada para chips de sincronización,
/// estados de trabajos HPC, etc).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w600,
  });

  final String label;
  final Color color;
  final Color background;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.round)),
      child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color)),
    );
  }
}

/// Pequeño punto de estado (disponible / advertencia / error).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8, this.ring = false});

  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: ring ? [BoxShadow(color: color.withValues(alpha: 0.13), blurRadius: 0, spreadRadius: 3)] : null,
      ),
    );
  }
}

/// Título de sección en mayúsculas pequeñas, usado sobre listas
/// (p.ej. "CARPETAS", "ARCHIVOS RECIENTES").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Fila de chips de filtro horizontal desplazable.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: option,
                selected: option == selected,
                onTap: () => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.blueLight : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.round),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.round),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.round),
            border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.blue : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de pestañas subrayadas, usada en HPC, álbum, alertas, detalle de
/// trabajo.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in options)
              InkWell(
                onTap: () => onSelected(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: option == selected ? AppColors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 13,
                      color: option == selected ? AppColors.blue : AppColors.textSecondary,
                      fontWeight: option == selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso lineal delgada con esquinas redondeadas.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({super.key, required this.value, required this.color, this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.background,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Icono dentro de un contenedor cuadrado redondeado con fondo de color
/// suave (patrón repetido en tarjetas de archivos, actividad, opciones).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 38,
    this.iconSize = 20,
    this.radius = AppRadius.sm,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Interruptor visual simple (toggle) de solo lectura, estilo boceto.
class SimpleToggle extends StatelessWidget {
  const SimpleToggle({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 22,
      padding: const EdgeInsets.all(2),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? AppColors.blue : AppColors.border,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
      ),
    );
  }
}
