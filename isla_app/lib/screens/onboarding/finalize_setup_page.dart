import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/isla_scaffold_background.dart';

class FinalizeSetupPage extends StatefulWidget {
  const FinalizeSetupPage({super.key});

  @override
  State<FinalizeSetupPage> createState() => _FinalizeSetupPageState();
}

class _FinalizeSetupPageState extends State<FinalizeSetupPage>
    with SingleTickerProviderStateMixin {
  static const double _minMinutes = 60;
  static const double _maxMinutes = 480;

  late AnimationController _glowController;
  double _minutes = 270;
  bool _gentleReminders = true;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              const _StepSixProgress(),
              const SizedBox(height: 24),
              _headerIcon(),
              const SizedBox(height: 18),
              Text(
                'Finalize Setup',
                style: GoogleFonts.manrope(
                  color: IslaColors.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Establish your digital sanctuary. Set your daily intention to begin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: IslaColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              GlassPanel(
                child: Column(
                  children: [
                    Text(
                      'DAILY FOCUS GOAL',
                      style: GoogleFonts.inter(
                        color: IslaColors.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _goalText(),
                    const SizedBox(height: 18),
                    _GradientSlider(
                      value: _minutes,
                      min: _minMinutes,
                      max: _maxMinutes,
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: IslaColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IslaColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gentle Reminders',
                            style: GoogleFonts.inter(
                              color: IslaColors.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Soft nudges to maintain focus',
                            style: GoogleFonts.inter(
                              color: IslaColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _gentleReminders,
                      onChanged: (v) => setState(() => _gentleReminders = v),
                      activeColor: IslaColors.surfaceContainerHigh,
                      activeTrackColor: IslaColors.primary,
                      inactiveThumbColor: IslaColors.surfaceContainerHighest,
                      inactiveTrackColor: IslaColors.surfaceContainer,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CyanGradientButton(
                label: 'Start First Session',
                trailing: const Icon(
                  Icons.arrow_forward_rounded,
                  color: IslaColors.onPrimaryContainer,
                  size: 18,
                ),
                onTap: () => context.goNamed('app'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIcon() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final blur = 5 + (_glowController.value * 20);
        return Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: IslaColors.surfaceContainerLow,
            border: Border.all(color: IslaColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: IslaColors.primary.withValues(alpha: 0.22),
                blurRadius: blur,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: IslaColors.primary,
            size: 34,
          ),
        );
      },
    );
  }

  Widget _goalText() {
    final total = _minutes.round();
    final hours = total ~/ 60;
    final mins = total % 60;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$hours',
            style: GoogleFonts.manrope(
              color: IslaColors.primary,
              fontWeight: FontWeight.w300,
              fontSize: 48,
            ),
          ),
          TextSpan(
            text: 'h ',
            style: GoogleFonts.manrope(
              color: IslaColors.onSurface,
              fontWeight: FontWeight.w300,
              fontSize: 30,
            ),
          ),
          TextSpan(
            text: mins.toString().padLeft(2, '0'),
            style: GoogleFonts.manrope(
              color: IslaColors.primary,
              fontWeight: FontWeight.w300,
              fontSize: 48,
            ),
          ),
          TextSpan(
            text: 'm',
            style: GoogleFonts.manrope(
              color: IslaColors.onSurface,
              fontWeight: FontWeight.w300,
              fontSize: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepSixProgress extends StatelessWidget {
  const _StepSixProgress();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isLast = index == 5;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isLast ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isLast ? IslaColors.cyanToBlue : null,
            color: isLast ? null : IslaColors.surfaceContainerHighest,
            boxShadow: isLast
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

class _GradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = ratio * width;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx.clamp(0.0, width);
            final next = min + ((dx / width) * (max - min));
            onChanged(next);
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx.clamp(0.0, width);
            final next = min + ((dx / width) * (max - min));
            onChanged(next);
          },
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  width: width,
                  decoration: BoxDecoration(
                    color: IslaColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  height: 6,
                  width: thumbX,
                  decoration: BoxDecoration(
                    gradient: IslaColors.cyanToBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Positioned(
                  left: (thumbX - 10).clamp(0.0, width - 20),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: IslaColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: IslaColors.primary.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: IslaColors.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
