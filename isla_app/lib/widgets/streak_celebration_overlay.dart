import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'confetti_overlay.dart';

/// Full-screen "a streak is born" celebration, shown after a session when the
/// daily streak goes up. Big glossy flame, count-up number, a week progress
/// bar and a commitment button — inspired by premium habit apps.
class StreakCelebrationOverlay extends StatefulWidget {
  final int streak;
  final List<bool> last7; // oldest → newest, index 6 == today
  final VoidCallback onContinue;

  const StreakCelebrationOverlay({
    super.key,
    required this.streak,
    required this.last7,
    required this.onContinue,
  });

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay> {
  bool _pressed = false;

  static const _orange = Color(0xFFFF7A1A);
  static const _amber = Color(0xFFFFB547);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ConfettiBurst.fire(context, particleCount: 30);
    });
  }

  String get _headline => widget.streak <= 1
      ? 'A streak is born!'
      : '${widget.streak}-day streak!';

  String get _sub => widget.streak <= 1
      ? 'Keep it up every day to help it grow.'
      : 'Don\'t break the chain — come back tomorrow.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF221206), Color(0xFF0A0A0C)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Glossy flame ───────────────────────────────────────────
                const _GlossyFlame(size: 150)
                    .animate()
                    .scale(
                      begin: const Offset(0.2, 0.2),
                      end: const Offset(1, 1),
                      duration: 700.ms,
                      curve: Curves.elasticOut,
                    )
                    .then()
                    .shimmer(duration: 1400.ms, color: Colors.white24),

                const SizedBox(height: 12),

                // ── Big number ─────────────────────────────────────────────
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: widget.streak),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => ShaderMask(
                    shaderCallback: (r) =>
                        const LinearGradient(colors: [_amber, _orange])
                            .createShader(r),
                    child: Text(
                      '$value',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Message + week bar card ────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _headline,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sub,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WeekBar(last7: widget.last7),
                    ],
                  ),
                )
                    .animate(delay: 350.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 20),

                // ── Commit button ──────────────────────────────────────────
                GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) {
                    setState(() => _pressed = false);
                    widget.onContinue();
                  },
                  onTapCancel: () => setState(() => _pressed = false),
                  child: AnimatedScale(
                    scale: _pressed ? 0.96 : 1,
                    duration: const Duration(milliseconds: 110),
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_amber, _orange]),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        'I\'m committed 🔥',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                )
                    .animate(delay: 600.ms)
                    .fadeIn()
                    .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Week progress bar with the flame on today ────────────────────────────────

class _WeekBar extends StatelessWidget {
  final List<bool> last7;
  const _WeekBar({required this.last7});

  static const _orange = Color(0xFFFF7A1A);
  static const _amber = Color(0xFFFFB547);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    // Fraction of the week filled up to & including today (index 6).
    final filled = last7.where((d) => d).length / 7.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  // Filled
                  Container(
                    height: 12,
                    width: (w * filled).clamp(14.0, w),
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_amber, _orange]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  // Flame head at the end of the filled portion
                  Positioned(
                    left: (w * filled).clamp(0.0, w - 26),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_fire_department_rounded,
                          color: _orange, size: 17),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day = now.subtract(Duration(days: 6 - i));
            final isToday = i == 6;
            return Text(
              letters[(day.weekday - 1) % 7],
              style: GoogleFonts.inter(
                color: isToday ? _amber : Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Glossy 3D-ish flame ──────────────────────────────────────────────────────

class _GlossyFlame extends StatelessWidget {
  final double size;
  const _GlossyFlame({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
            blurRadius: 70,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFF6A00), Color(0xFFFFC24B)],
        ).createShader(rect),
        child: Icon(Icons.local_fire_department_rounded,
            color: Colors.white, size: size),
      ),
    );
  }
}
