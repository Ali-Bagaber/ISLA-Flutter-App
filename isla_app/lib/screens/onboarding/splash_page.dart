import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/breathing_glow.dart';
import '../../widgets/cyan_gradient_button.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 100), _controller.forward);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: Stack(
        children: [
          // Ambient background glows (top-right + bottom-left)
          Positioned(
            top: -80,
            right: -40,
            child: _blurBlob(
              400,
              IslaColors.primary.withValues(alpha: 0.05),
              120,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: _blurBlob(
              300,
              IslaColors.tertiary.withValues(alpha: 0.05),
              100,
            ),
          ),
          // Breathing radial glow
          const BreathingGlow(),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          const _LogoOrb(),
                          const SizedBox(height: 16),
                          Text(
                            'ISLA',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 5,
                              fontSize: 13,
                              color: IslaColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Headline
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.manrope(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                letterSpacing: -1.5,
                                color: IslaColors.onSurface,
                              ),
                              children: [
                                const TextSpan(text: 'Focus with\n'),
                                TextSpan(
                                  text: 'ISLA',
                                  style: TextStyle(
                                    foreground: Paint()
                                      ..shader =
                                          IslaColors.cyanToBlue.createShader(
                                        const Rect.fromLTWH(0, 0, 200, 80),
                                      ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Step into a digital sanctuary designed for deep work and intentional clarity.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              height: 1.6,
                              color: IslaColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // CTA
                FadeTransition(
                  opacity: _fade,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 48,
                      left: 32,
                      right: 32,
                    ),
                    child: Column(
                      children: [
                        CyanGradientButton(
                          label: 'GET STARTED',
                          onTap: () => context.pushNamed('valueProposition'),
                        ),
                        const SizedBox(height: 28),
                        const _PageDots(current: 0, total: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurBlob(double size, Color color, double blur) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LogoOrb extends StatefulWidget {
  const _LogoOrb();

  @override
  State<_LogoOrb> createState() => _LogoOrbState();
}

class _LogoOrbState extends State<_LogoOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: IslaColors.primary.withValues(alpha: 0.2)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: IslaColors.primary
                        .withValues(alpha: 0.05 + (_glow.value * 0.08)),
                  ),
                ),
              ),
              const Icon(Icons.circle, color: IslaColors.primary, size: 36),
            ],
          ),
        );
      },
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i == current
                ? IslaColors.primary
                : IslaColors.surfaceContainerHighest,
            boxShadow: i == current
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
