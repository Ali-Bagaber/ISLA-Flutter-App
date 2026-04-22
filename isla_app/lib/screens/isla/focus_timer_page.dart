import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/isla_scaffold_background.dart';

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _running = false;
  int _seconds = 30 * 60;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: IslaColors.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      'Focus Session',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: IslaColors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  _StepPill(label: 'Plan', done: true),
                  SizedBox(width: 8),
                  _StepPill(label: 'Focus', active: true),
                  SizedBox(width: 8),
                  _StepPill(label: 'Review'),
                ],
              ),
              const SizedBox(height: 12),
              _infoCard(),
              const SizedBox(height: 10),
              _aiTipCard(),
              const SizedBox(height: 18),
              Center(child: _timerRing()),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _seconds = 30 * 60),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CyanGradientButton(
                      label: _running ? 'PAUSE' : 'PLAY',
                      onTap: () => setState(() => _running = !_running),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _seconds = 5 * 60),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _seconds = max(60, _seconds - 300)),
                      child: const Text('-5 min'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _seconds += 300),
                      child: const Text('+5 min'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _checklistCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IslaColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IslaColors.primary.withValues(alpha: 0.15)),
      ),
      child: Text(
        'Deep Work • 30 minutes • Zero interruptions',
        style: GoogleFonts.inter(
          color: IslaColors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _aiTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IslaColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: IslaColors.cyanToBlue,
              boxShadow: [
                BoxShadow(
                  color: IslaColors.primary.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI Tip: Finish the current subtopic before checking notifications.',
              style: GoogleFonts.inter(
                color: IslaColors.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerRing() {
    final progress = (_seconds / (30 * 60)).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.05),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _TimerRingPainter(progress: progress),
                ),
                Text(
                  _formatTime(_seconds),
                  style: GoogleFonts.manrope(
                    color: IslaColors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _checklistCard() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: IslaColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IslaColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checklist',
              style: GoogleFonts.manrope(
                color: IslaColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const _CheckItem(text: 'Review stack operations', done: true),
            const _CheckItem(text: 'Practice queue example', done: false),
            const _CheckItem(text: 'Summarize key differences', done: false),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;

  _TimerRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF161A28);

    canvas.drawArc(rect, -pi / 2, pi * 2, false, track);

    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: (pi * 2) - (pi / 2),
      colors: const [IslaColors.primary, IslaColors.tertiary],
    );

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(rect, -pi / 2, (pi * 2) * progress, false, fill);
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepPill({
    required this.label,
    this.done = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: active ? IslaColors.cyanToBlue : null,
        color: active ? null : IslaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: done
            ? Border.all(color: IslaColors.primary.withValues(alpha: 0.6))
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? IslaColors.onPrimaryContainer : IslaColors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool done;

  const _CheckItem({required this.text, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? IslaColors.primary : IslaColors.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: IslaColors.onSurface,
                fontSize: 13,
                decoration:
                    done ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
