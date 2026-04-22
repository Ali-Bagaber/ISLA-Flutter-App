import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class CyanGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const CyanGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: IslaColors.cyanToBlue,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: IslaColors.primary.withValues(alpha: 0.15),
              blurRadius: 32,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1.2,
                color: IslaColors.onPrimaryContainer,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
