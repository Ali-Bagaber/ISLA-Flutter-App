import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/user_settings_service.dart';
import '../../widgets/cyan_gradient_button.dart';
import '../../widgets/isla_scaffold_background.dart';

enum _StudyGoal {
  aceExams,
  buildHabit,
  learnNew,
  improveGrades,
  stayConsistent,
}

class FinalizeSetupScreen extends StatefulWidget {
  const FinalizeSetupScreen({super.key});

  @override
  State<FinalizeSetupScreen> createState() => _FinalizeSetupScreenState();
}

class _FinalizeSetupScreenState extends State<FinalizeSetupScreen> {
  _StudyGoal _selectedGoal = _StudyGoal.aceExams;
  bool _saving = false;

  /// Persist the onboarding choices + flip onboardingComplete to true so
  /// AuthGate sends the user straight to the app on subsequent launches.
  Future<void> _finishSetup() async {
    if (_saving) return;
    setState(() => _saving = true);

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await UserSettingsService.saveStudyPlan(
          onboardingComplete: true,
          goal: _selectedGoal.name,
        );
        if (!mounted) return;
        context.goNamed('app');
        return;
      } catch (e) {
        final isTransient = e.toString().contains('INTERNAL ASSERTION') ||
            e.toString().contains('Unexpected state');
        if (attempt == 0 && isTransient) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not save — please check your connection and try again.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }
  }

  static const _goalLabels = {
    _StudyGoal.aceExams: 'Ace My Exams',
    _StudyGoal.buildHabit: 'Build a Habit',
    _StudyGoal.learnNew: 'Learn Something New',
    _StudyGoal.improveGrades: 'Improve Grades',
    _StudyGoal.stayConsistent: 'Stay Consistent',
  };

  static const _goalIcons = {
    _StudyGoal.aceExams: Icons.emoji_events_rounded,
    _StudyGoal.buildHabit: Icons.repeat_rounded,
    _StudyGoal.learnNew: Icons.explore_rounded,
    _StudyGoal.improveGrades: Icons.trending_up_rounded,
    _StudyGoal.stayConsistent: Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IslaColors.background,
      body: IslaScaffoldBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: _buildGoalStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalStep() {
    return Padding(
      key: const ValueKey('goal'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 16),
            color: IslaColors.onSurfaceVariant,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 12),
          Text(
            "What's your\nmain study goal?",
            style: GoogleFonts.manrope(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: IslaColors.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the goal that best describes what you want to achieve.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: IslaColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _StudyGoal.values.map((goal) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GoalTile(
                    icon: _goalIcons[goal]!,
                    label: _goalLabels[goal]!,
                    selected: _selectedGoal == goal,
                    onTap: () => setState(() => _selectedGoal = goal),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          const _PageDots(current: 2, total: 3),
          const SizedBox(height: 24),
          CyanGradientButton(
            label: _saving ? 'Setting up...' : 'Get Started',
            onTap: _saving ? () {} : () => _finishSetup(),
          ),
        ],
      ),
    );
  }

}

// ── Goal tile ─────────────────────────────────────────────────────────────────

class _GoalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.icon,
    required this.label,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? IslaColors.primary.withValues(alpha: 0.08)
                : IslaColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? IslaColors.primary.withValues(alpha: 0.5)
                  : IslaColors.outlineVariant,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: IslaColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
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
                  color: selected
                      ? IslaColors.primary.withValues(alpha: 0.12)
                      : IslaColors.surfaceContainerHighest,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? IslaColors.primary
                      : IslaColors.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: IslaColors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? IslaColors.primary : IslaColors.outline,
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

// ── Page dots ──────────────────────────────────────────────────────────────────

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
