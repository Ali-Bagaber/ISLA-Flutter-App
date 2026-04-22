import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/isla_scaffold_background.dart';

enum _IntentionMode { deepWork, study, creative }

class SelectIntentionPage extends StatefulWidget {
  const SelectIntentionPage({super.key});

  @override
  State<SelectIntentionPage> createState() => _SelectIntentionPageState();
}

class _SelectIntentionPageState extends State<SelectIntentionPage> {
  _IntentionMode _selected = _IntentionMode.deepWork;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const _StepDots(current: 2, total: 4),
              const SizedBox(height: 24),
              Text(
                'Select your intention',
                style: GoogleFonts.manrope(
                  color: IslaColors.onSurface,
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the mode that fits your current task.',
                style: GoogleFonts.inter(
                  color: IslaColors.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 18),
              _ModeTile(
                icon: Icons.blur_on_rounded,
                title: 'Deep Work',
                subtitle: 'Zero distractions',
                selected: _selected == _IntentionMode.deepWork,
                onTap: () =>
                    setState(() => _selected = _IntentionMode.deepWork),
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.menu_book_rounded,
                title: 'Study',
                subtitle: 'Structured retention',
                selected: _selected == _IntentionMode.study,
                onTap: () => setState(() => _selected = _IntentionMode.study),
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.palette_outlined,
                title: 'Creative',
                subtitle: 'Open exploration',
                selected: _selected == _IntentionMode.creative,
                onTap: () =>
                    setState(() => _selected = _IntentionMode.creative),
              ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'BACK',
                      style: GoogleFonts.inter(
                        color: IslaColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CyanGradientButton(
                      label: 'NEXT',
                      onTap: () => context.pushNamed('finalizeSetup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? IslaColors.surfaceContainerHigh.withValues(alpha: 0.86)
                : IslaColors.surfaceContainerLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? IslaColors.primary : IslaColors.outlineVariant,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: IslaColors.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IslaColors.surfaceContainerHighest,
                ),
                child: Icon(icon, color: IslaColors.onSurfaceVariant, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: IslaColors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: selected
                            ? IslaColors.primary
                            : IslaColors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? IslaColors.primary : IslaColors.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: IslaColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;

  const _StepDots({required this.current, required this.total});

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
            boxShadow: active
                ? [
                    BoxShadow(
                      color: IslaColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
