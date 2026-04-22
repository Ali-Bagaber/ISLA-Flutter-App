import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/isla_scaffold_background.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.menu_rounded,
                        color: IslaColors.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      'ISLA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: IslaColors.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: IslaColors.surfaceContainerHighest,
                    child:
                        Icon(Icons.person, color: IslaColors.primary, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.manrope(
                    color: IslaColors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    height: 1.05,
                  ),
                  children: [
                    const TextSpan(text: 'Good Morning,\n'),
                    TextSpan(
                      text: 'Alex',
                      style: TextStyle(
                        foreground: Paint()
                          ..shader = IslaColors.cyanToBlue.createShader(
                            const Rect.fromLTWH(0, 0, 160, 60),
                          ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  children: [
                    SizedBox(
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(170, 170),
                            painter: _ArcProgressPainter(progress: 0.76),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '76%',
                                style: GoogleFonts.manrope(
                                  color: IslaColors.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 38,
                                ),
                              ),
                              Text(
                                'Daily Score',
                                style: GoogleFonts.inter(
                                  color: IslaColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _ProgressStat(label: 'Focused', value: '3h 25m'),
                        _ProgressStat(label: 'Tasks', value: '6/8'),
                        _ProgressStat(label: 'Streak', value: '5d'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CyanGradientButton(
                label: 'Start Session',
                onTap: () => context.pushNamed('focus'),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: IslaColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IslaColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: IslaColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Continue your Deep Work flow from yesterday.',
                        style: GoogleFonts.inter(
                          color: IslaColors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Resume',
                        style: GoogleFonts.inter(
                          color: IslaColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Recent Activity',
                style: GoogleFonts.manrope(
                  color: IslaColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: const [
                    _RecentActivityItem(
                      title: 'Reviewed Data Structures notes',
                      subtitle: 'Completed 32 min ago',
                      done: true,
                    ),
                    _RecentActivityItem(
                      title: 'Generate quiz for OOP chapter',
                      subtitle: 'Pending',
                      done: false,
                    ),
                    _RecentActivityItem(
                      title: 'Finalize session checklist',
                      subtitle: 'Completed 2h ago',
                      done: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcProgressPainter extends CustomPainter {
  final double progress;

  _ArcProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = 12.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF161A28)
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - (stroke / 2));
    const start = -pi * 0.85;
    const total = pi * 1.7;

    canvas.drawArc(rect, start, total, false, trackPaint);

    final gradient = SweepGradient(
      startAngle: start,
      endAngle: start + total,
      colors: const [IslaColors.primary, IslaColors.tertiary],
    );

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(
        rect, start, total * progress.clamp(0, 1), false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProgressStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            color: IslaColors.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: IslaColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;

  const _RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IslaColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.schedule_rounded,
            color: done ? IslaColors.primary : IslaColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: IslaColors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: IslaColors.onSurfaceVariant,
                    fontSize: 12,
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
