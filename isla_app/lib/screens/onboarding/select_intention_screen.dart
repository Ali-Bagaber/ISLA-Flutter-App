import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/isla_scaffold_background.dart';

class SelectIntentionScreen extends StatelessWidget {
  const SelectIntentionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: IslaColors.onSurfaceVariant,
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Study Smarter.\n',
                        style: GoogleFonts.manrope(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: IslaColors.onSurface,
                          height: 1.15,
                        ),
                      ),
                      TextSpan(
                        text: 'Achieve More.',
                        style: GoogleFonts.manrope(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          foreground: Paint()
                            ..shader = IslaColors.cyanToBlue.createShader(
                              const Rect.fromLTWH(0, 0, 300, 60),
                            ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Everything you need to study smarter, not harder.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: IslaColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                const _FeatureCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Powered Guidance',
                  subtitle:
                      'Instant help, smart summaries, and study plans tailored to you.',
                ),
                const SizedBox(height: 12),
                const _FeatureCard(
                  icon: Icons.timer_rounded,
                  title: 'Deep Focus Tools',
                  subtitle:
                      'Pomodoro sessions, distraction tracking, and flow-state timers.',
                ),
                const SizedBox(height: 12),
                const _FeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Track & Improve',
                  subtitle:
                      'Visualise progress with insights on streaks, hours, and tasks.',
                ),
                const Spacer(),
                const _PageDots(current: 1, total: 4),
                const SizedBox(height: 28),
                CyanGradientButton(
                  label: 'Next',
                  onTap: () => context.pushNamed('finalizeSetup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: IslaColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IslaColors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: IslaColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: IslaColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, color: IslaColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: IslaColors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: IslaColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int current;
  final int total;

  const _PageDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? IslaColors.cyanToBlue : null,
            color: active ? null : IslaColors.surfaceContainerHighest,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: IslaColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
