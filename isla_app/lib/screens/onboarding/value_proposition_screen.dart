import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';

class ValuePropositionScreen extends StatelessWidget {
  const ValuePropositionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Clean dark navy backdrop — no competing artwork, so the small
          // lighthouse logo at the top is the only focal point on the page.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.1,
                colors: [
                  Color(0xFF0A1B33), // soft glow behind the logo
                  Color(0xFF030D1B), // deep navy edges
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/images/isla_logo_1024.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Welcome to ISLA',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: IslaColors.onSurface,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your personal AI study partner for deeper focus\nand better learning every day.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.65,
                      color: IslaColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 3),
                  const _PageDots(current: 0, total: 4),
                  const SizedBox(height: 28),
                  CyanGradientButton(
                    label: "Let's Get Started",
                    onTap: () => context.pushNamed('intention'),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.goNamed('app'),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.inter(
                              color: IslaColors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: 'Sign In',
                            style: GoogleFonts.inter(
                              color: IslaColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
