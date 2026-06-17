import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'confetti_overlay.dart';

/// Full-screen celebration overlay shown when a focus session completes.
/// Displays a glowing checkmark, animated stats, and a Continue button.
/// Matches ISLA's dark navy / cyan aesthetic.
class SessionCelebrationOverlay extends StatefulWidget {
  final int xpScore;      // 0–100 session score
  final int focusMinutes;
  final int cycles;
  final VoidCallback onContinue;

  const SessionCelebrationOverlay({
    super.key,
    required this.xpScore,
    required this.focusMinutes,
    required this.cycles,
    required this.onContinue,
  });

  @override
  State<SessionCelebrationOverlay> createState() =>
      _SessionCelebrationOverlayState();
}

class _SessionCelebrationOverlayState
    extends State<SessionCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();
    // Confetti bursts to celebrate finishing the session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final w = MediaQuery.of(context).size.width;
      ConfettiBurst.fire(context, particleCount: 36);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          ConfettiBurst.fire(context,
              origin: Offset(w * 0.25, 160), particleCount: 18);
        }
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          ConfettiBurst.fire(context,
              origin: Offset(w * 0.75, 160), particleCount: 18);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [
              Color(0xFF0A1B33),
              Color(0xFF020B18),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Glowing checkmark icon ─────────────────────────────────────
              const _GlowingCheckIcon()
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 28),

              // ── Title ──────────────────────────────────────────────────────
              const Text(
                'Session Complete!',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              )
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),

              const SizedBox(height: 8),

              Text(
                'You focused hard. Keep the momentum!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.2,
                ),
              )
                  .animate(delay: 550.ms)
                  .fadeIn(duration: 350.ms),

              const Spacer(flex: 1),

              // ── Stat cards ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CelebrationStatCard(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFFFFD166),
                      label: 'XP Earned',
                      targetValue: widget.xpScore,
                      suffix: ' XP',
                      delay: 650.ms,
                    ),
                    const SizedBox(width: 12),
                    _CelebrationStatCard(
                      icon: Icons.timer_rounded,
                      iconColor: const Color(0xFF81ECFF),
                      label: 'Focus Time',
                      targetValue: widget.focusMinutes,
                      suffix: ' min',
                      delay: 780.ms,
                    ),
                    const SizedBox(width: 12),
                    _CelebrationStatCard(
                      icon: Icons.repeat_rounded,
                      iconColor: const Color(0xFF6C63FF),
                      label: 'Cycles',
                      targetValue: widget.cycles,
                      suffix: '',
                      delay: 900.ms,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Continue button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _buttonPressed = true),
                  onTapUp: (_) {
                    setState(() => _buttonPressed = false);
                    widget.onContinue();
                  },
                  onTapCancel: () => setState(() => _buttonPressed = false),
                  child: AnimatedScale(
                    scale: _buttonPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81ECFF), Color(0xFF4A90D9)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF81ECFF).withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                    .animate(delay: 1100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.4, end: 0, duration: 400.ms, curve: Curves.easeOut),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glowing animated checkmark ─────────────────────────────────────────────

class _GlowingCheckIcon extends StatelessWidget {
  const _GlowingCheckIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer soft glow ring
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF81ECFF).withValues(alpha: 0.06),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81ECFF).withValues(alpha: 0.25),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
        // Inner circle
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF2DCCFF), Color(0xFF2A7BD4)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81ECFF).withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
        // Pulse ring animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF81ECFF).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.3, 1.3),
              duration: 1600.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 1600.ms),
      ],
    );
  }
}

// ── Animated stat card with count-up number ────────────────────────────────

class _CelebrationStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int targetValue;
  final String suffix;
  final Duration delay;

  const _CelebrationStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.targetValue,
    required this.suffix,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: targetValue),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Text(
                '$value$suffix',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          .animate(delay: delay)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.4, end: 0, duration: 350.ms, curve: Curves.easeOut),
    );
  }
}
