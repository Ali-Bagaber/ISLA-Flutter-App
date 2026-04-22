import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class BreathingGlow extends StatefulWidget {
  const BreathingGlow({super.key});

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  IslaColors.primary
                      .withValues(alpha: 0.04 + (_controller.value * 0.06)),
                  IslaColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
