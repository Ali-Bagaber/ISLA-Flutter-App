import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight particle-based confetti burst — no external package.
///
/// Fire it from anywhere with:
/// ```dart
/// ConfettiBurst.fire(context);                 // burst from top-center
/// ConfettiBurst.fire(context, origin: pos);    // burst from a point
/// ```
/// It inserts a transparent, tap-through overlay that auto-removes when done.
class ConfettiBurst {
  static void fire(
    BuildContext context, {
    Offset? origin,
    int particleCount = 28,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final media = MediaQuery.of(context);
    final start = origin ??
        Offset(media.size.width / 2, media.size.height * 0.22);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiLayer(
        origin: start,
        particleCount: particleCount,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiLayer extends StatefulWidget {
  final Offset origin;
  final int particleCount;
  final VoidCallback onDone;

  const _ConfettiLayer({
    required this.origin,
    required this.particleCount,
    required this.onDone,
  });

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  static const _colors = [
    Color(0xFF81ECFF), // cyan
    Color(0xFF4A90D9), // blue
    Color(0xFFFFD166), // gold
    Color(0xFF6C63FF), // violet
    Color(0xFF10B981), // green
    Color(0xFFFF6B9D), // pink
  ];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = List.generate(widget.particleCount, (_) {
      // Explode outward + slightly upward, then gravity takes over.
      final angle = -pi / 2 + (rnd.nextDouble() - 0.5) * pi * 1.1;
      final speed = 220 + rnd.nextDouble() * 320;
      return _Particle(
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: _colors[rnd.nextInt(_colors.length)],
        size: 6 + rnd.nextDouble() * 8,
        rotation: rnd.nextDouble() * pi * 2,
        rotationSpeed: (rnd.nextDouble() - 0.5) * 12,
        isCircle: rnd.nextBool(),
      );
    });

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(
          particles: _particles,
          origin: widget.origin,
          t: _ctrl.value,
        ),
      ),
    );
  }
}

class _Particle {
  final Offset velocity; // px/sec
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isCircle;

  const _Particle({
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final Offset origin;
  final double t; // 0..1

  static const _gravity = 900.0; // px/sec^2
  static const _duration = 1.6; // seconds (matches controller)

  _ConfettiPainter({
    required this.particles,
    required this.origin,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = t * _duration;
    // Fade out over the last 35% of the animation.
    final opacity = t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);

    for (final p in particles) {
      final dx = origin.dx + p.velocity.dx * time;
      final dy = origin.dy +
          p.velocity.dy * time +
          0.5 * _gravity * time * time;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + p.rotationSpeed * time);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
