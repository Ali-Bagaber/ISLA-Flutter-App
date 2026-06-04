import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// The canonical ISLA card — one consistent radius, padding, border and soft
/// shadow used across every screen. Pass [glow] for a cyan-tinted highlight,
/// or [onTap] to make it pressable (with the shared press-scale).
class IslaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final Color? glowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const IslaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.glow = false,
    this.glowColor,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = glowColor ?? AppTheme.primaryColor;

    Widget card = Container(
      width: double.infinity,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glow
              ? accent.withValues(alpha: 0.45)
              : AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.6),
          width: glow ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glow
                ? accent.withValues(alpha: isDark ? 0.16 : 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
            blurRadius: glow ? 24 : 16,
            spreadRadius: glow ? -4 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      card = Pressable(onTap: onTap, child: card);
    }
    return card;
  }
}
