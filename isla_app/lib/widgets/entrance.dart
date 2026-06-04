import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Consistent entrance animation used across screens: a soft fade + slide-up.
/// Use [index] to stagger items in a list so they cascade in.
extension IslaEntrance on Widget {
  Widget entrance({int index = 0, double dy = 0.12, Duration? duration}) {
    final d = duration ?? 360.ms;
    return animate(delay: (55 * index).ms)
        .fadeIn(duration: d, curve: Curves.easeOut)
        .slideY(begin: dy, end: 0, duration: d, curve: Curves.easeOutCubic);
  }
}
