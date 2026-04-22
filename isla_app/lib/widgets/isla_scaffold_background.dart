import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'breathing_glow.dart';

class IslaScaffoldBackground extends StatelessWidget {
  final Widget child;
  final bool useSafeArea;

  const IslaScaffoldBackground({
    super.key,
    required this.child,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = useSafeArea ? SafeArea(child: child) : child;

    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -40,
          child: _blurBlob(
            400,
            IslaColors.primary.withValues(alpha: 0.05),
            120,
          ),
        ),
        Positioned(
          bottom: -80,
          left: -40,
          child: _blurBlob(
            300,
            IslaColors.tertiary.withValues(alpha: 0.05),
            100,
          ),
        ),
        const BreathingGlow(),
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _blurBlob(double size, Color color, double blur) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: const SizedBox.expand(),
      ),
    );
  }
}
