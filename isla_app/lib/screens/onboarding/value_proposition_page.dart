import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/isla_scaffold_background.dart';

class ValuePropositionPage extends StatefulWidget {
  const ValuePropositionPage({super.key});

  @override
  State<ValuePropositionPage> createState() => _ValuePropositionPageState();
}

class _ValuePropositionPageState extends State<ValuePropositionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'ISLA',
                    style: GoogleFonts.manrope(
                      color: IslaColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.goNamed('app'),
                    icon: const Icon(Icons.close_rounded),
                    color: IslaColors.onSurfaceVariant,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final spread = 0.2 + (_pulse.value * 0.25);
                  return Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: IslaColors.primary.withValues(alpha: spread),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: IslaColors.primary.withValues(alpha: 0.22),
                          blurRadius: 30 + (30 * _pulse.value),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: IslaColors.primary,
                      size: 48,
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(
                'EVOLUTION OF FOCUS',
                style: GoogleFonts.inter(
                  color: IslaColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Reclaim your\ntime',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: IslaColors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 54,
                  height: 0.95,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Designed for deep work and mindful productivity. Step into a sanctuary of focus.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: IslaColors.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              CyanGradientButton(
                label: 'Continue to Focus',
                onTap: () => context.pushNamed('intention'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Methodology content coming soon.'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: IslaColors.outlineVariant),
                    backgroundColor:
                        IslaColors.surfaceContainerLow.withValues(alpha: 0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Learn the Methodology',
                    style: GoogleFonts.inter(
                      color: IslaColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PageDots(current: 1, total: 4),
            ],
          ),
        ),
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
      children: List.generate(total, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? IslaColors.cyanToBlue : null,
            color: active ? null : IslaColors.surfaceContainerHighest,
          ),
        );
      }),
    );
  }
}
