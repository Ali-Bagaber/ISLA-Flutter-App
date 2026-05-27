import 'package:flutter/material.dart';

/// Wrap any tappable card / button to add a subtle hover lift on web & desktop:
///   • Soft scale 1.0 → [scale] (default 1.03)
///   • Optional cyan-tinted glow shadow underneath
///   • Pointer cursor turns into [SystemMouseCursors.click]
///
/// On mobile (no hover), this is a no-op — children render unchanged.
///
/// Duration ~220ms with easeOut so the motion stays subtle and professional.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool glow;
  final Color? glowColor;
  final Duration duration;

  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.glow = false,
    this.glowColor,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final glowColor =
        widget.glowColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOut,
          decoration: widget.glow
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _hovering
                      ? [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
