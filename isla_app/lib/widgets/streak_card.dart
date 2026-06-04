import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium animated streak card — flickering flame, count-up number and a
/// 7-day activity row. Pure Flutter animation, no external package.
///
/// [last7] is 7 booleans, oldest → newest (index 6 == today), true if the user
/// studied that day.
class StreakCard extends StatefulWidget {
  final int streak;
  final int bestStreak;
  final List<bool> last7;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.streak,
    required this.last7,
    this.bestStreak = 0,
    this.onTap,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flame;

  static const _flameOrange = Color(0xFFFF7A1A);
  static const _flameAmber = Color(0xFFFFB547);

  @override
  void initState() {
    super.initState();
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = widget.streak > 0;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F1A1F);
    final onMuted = isDark ? Colors.white60 : const Color(0xFF5A6770);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1208), const Color(0xFF0B1420)]
                : [const Color(0xFFFFF3E6), const Color(0xFFEAF2F8)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? _flameOrange.withValues(alpha: isDark ? 0.35 : 0.4)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _flameOrange.withValues(alpha: isDark ? 0.18 : 0.12),
                    blurRadius: 28,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFlame(active),
                const SizedBox(width: 14),
                Expanded(child: _buildNumber(active, onSurface, onMuted)),
                if (widget.bestStreak > 0)
                  _buildBestBadge(isDark, onMuted),
              ],
            ),
            const SizedBox(height: 16),
            _buildWeekRow(isDark, onMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildFlame(bool active) {
    return AnimatedBuilder(
      animation: _flame,
      builder: (_, __) {
        final t = _flame.value; // 0..1
        final glow = active ? (0.35 + t * 0.35) : 0.0;
        final scale = active ? (1.0 + t * 0.08) : 1.0;
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: active
                  ? [
                      _flameAmber.withValues(alpha: 0.30),
                      _flameOrange.withValues(alpha: 0.05),
                    ]
                  : [Colors.grey.withValues(alpha: 0.15), Colors.transparent],
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _flameOrange.withValues(alpha: glow),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: active
                      ? const [_flameOrange, _flameAmber]
                      : [Colors.grey.shade500, Colors.grey.shade400],
                ).createShader(rect),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 34),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumber(bool active, Color onSurface, Color onMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.streak),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Text(
                '$value',
                style: GoogleFonts.manrope(
                  color: active ? _flameOrange : onMuted,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                active ? 'day streak' : 'days',
                style: GoogleFonts.inter(
                  color: onMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          active ? _motivation(widget.streak) : 'Study today to start a streak 🔥',
          style: GoogleFonts.inter(color: onMuted, fontSize: 11.5, height: 1.3),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBestBadge(bool isDark, Color onMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('BEST',
              style: GoogleFonts.inter(
                  color: onMuted, fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text('${widget.bestStreak}',
              style: GoogleFonts.manrope(
                  color: _flameAmber, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildWeekRow(bool isDark, Color onMuted) {
    // last7 oldest→newest; today is index 6.
    final now = DateTime.now();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.last7.length, (i) {
        final day = now.subtract(Duration(days: widget.last7.length - 1 - i));
        final studied = widget.last7[i];
        final isToday = i == widget.last7.length - 1;
        final letter = letters[(day.weekday - 1) % 7];
        return Column(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 250 + i * 40),
              curve: Curves.easeOut,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: studied
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_flameAmber, _flameOrange],
                      )
                    : null,
                color: studied
                    ? null
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: _flameOrange, width: 1.6)
                    : null,
              ),
              child: studied
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : (isToday
                      ? Icon(Icons.circle, color: _flameOrange.withValues(alpha: 0.6), size: 6)
                      : null),
            ),
            const SizedBox(height: 5),
            Text(letter,
                style: GoogleFonts.inter(
                    color: isToday ? _flameOrange : onMuted,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
          ],
        );
      }),
    );
  }

  String _motivation(int streak) {
    if (streak >= 30) return 'A full month — unstoppable! 🏆';
    if (streak >= 14) return 'Two weeks strong — real habit forming.';
    if (streak >= 7) return 'A whole week! Keep the fire alive.';
    if (streak >= 3) return 'Nice momentum — don\'t break the chain!';
    return 'Great start — come back tomorrow!';
  }
}

/// Tiny helper to derive the last-7-days activity list from a set of study days.
List<bool> last7FromStudyDays(Set<DateTime> studyDays) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return studyDays.contains(day);
  });
}

/// Longest run of consecutive studied days anywhere in [studyDays].
int bestStreakFromStudyDays(Set<DateTime> studyDays) {
  if (studyDays.isEmpty) return 0;
  final sorted = studyDays.toList()..sort();
  var best = 1, run = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      run++;
      best = max(best, run);
    } else {
      run = 1;
    }
  }
  return best;
}
