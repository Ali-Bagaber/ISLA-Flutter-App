import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
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
  int _step = 0;
  _StudyGoal _selectedGoal = _StudyGoal.aceExams;
  String _studyFocus = 'Operating Systems';
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  int _sessionMinutes = 25;
  /// Days the user plans to study. 1=Mon … 7=Sun. Default: every day.
  Set<int> _studyDays = {1, 2, 3, 4, 5, 6, 7};
  bool _saving = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// Persist the onboarding choices + flip onboardingComplete to true so
  /// AuthGate sends the user straight to the app on subsequent launches.
  Future<void> _finishSetup() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UserSettingsService.saveStudyPlan(
        onboardingComplete: true,
        goal: _selectedGoal.name,
        focusSubject: _studyFocus,
        deadline: _deadline,
        sessionMinutes: _sessionMinutes,
        studyDays: _studyDays.toList()..sort(),
      );
      // Mirror sessionMinutes into the focus prefs so the Pomodoro timer
      // picks it up the next time the user starts a session.
      await UserSettingsService.saveFocus(workMinutes: _sessionMinutes);
      if (!mounted) return;
      context.goNamed('app');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
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

  static const _subjects = [
    'Operating Systems',
    'Data Structures',
    'Mathematics',
    'Database Systems',
    'Software Engineering',
    'Computer Networks',
    'Other',
  ];

  static const _sessionOptions = [15, 25, 50];

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
            child: _step == 0 ? _buildGoalStep() : _buildPersonalizeStep(),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
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
          const _PageDots(current: 2, total: 4),
          const SizedBox(height: 24),
          CyanGradientButton(
            label: 'Continue',
            onTap: () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizeStep() {
    final d = _deadline;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final deadlineStr = '${d.day} ${months[d.month]} ${d.year}';

    return Padding(
      key: const ValueKey('personalize'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: IslaColors.onSurfaceVariant,
            onPressed: () => setState(() => _step = 0),
          ),
          const SizedBox(height: 12),
          Text(
            "Let's personalize\nISLA for you.",
            style: GoogleFonts.manrope(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: IslaColors.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A few quick details to help ISLA fit your needs.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: IslaColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          const _FormLabel('Study Focus'),
          const SizedBox(height: 8),
          _DropdownField(
            value: _studyFocus,
            items: _subjects,
            onChanged: (v) => setState(() => _studyFocus = v),
          ),
          const SizedBox(height: 16),
          const _FormLabel('Study Deadline'),
          const SizedBox(height: 8),
          _TappableField(
            label: deadlineStr,
            icon: Icons.calendar_today_outlined,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deadline,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: IslaColors.primary,
                      onPrimary: IslaColors.onPrimary,
                      surface: IslaColors.surfaceContainerHigh,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _deadline = picked);
            },
          ),
          const SizedBox(height: 16),
          const _FormLabel('Session Goal Time'),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_sessionOptions.length, (i) {
              final mins = _sessionOptions[i];
              final active = _sessionMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < _sessionOptions.length - 1 ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _sessionMinutes = mins),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        color: active
                            ? IslaColors.primary.withValues(alpha: 0.1)
                            : IslaColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? IslaColors.primary.withValues(alpha: 0.5)
                              : IslaColors.outlineVariant,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$mins',
                            style: GoogleFonts.manrope(
                              color: active
                                  ? IslaColors.primary
                                  : IslaColors.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'min',
                            style: GoogleFonts.inter(
                              color: IslaColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const _FormLabel('Study Days'),
          const SizedBox(height: 4),
          Text(
            'Which days of the week do you plan to study? You\'ll get a gentle nudge if you miss one.',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: IslaColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              final day = i + 1; // 1=Mon … 7=Sun
              final selected = _studyDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        if (_studyDays.length > 1) _studyDays.remove(day);
                      } else {
                        _studyDays.add(day);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? IslaColors.primary.withValues(alpha: 0.14)
                            : IslaColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? IslaColors.primary.withValues(alpha: 0.55)
                              : IslaColors.outlineVariant,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _dayLabels[i],
                          style: GoogleFonts.inter(
                            color: selected
                                ? IslaColors.primary
                                : IslaColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => setState(
                () => _studyDays = {1, 2, 3, 4, 5, 6, 7},
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Every day',
                style: GoogleFonts.inter(
                  color: _studyDays.length == 7
                      ? IslaColors.primary
                      : IslaColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          const _PageDots(current: 3, total: 4),
          const SizedBox(height: 24),
          CyanGradientButton(
            label: _saving ? 'Saving…' : 'Finish Setup',
            onTap: _saving ? () {} : _finishSetup,
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

// ── Form helpers ───────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: IslaColors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TappableField({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: IslaColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IslaColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: IslaColors.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: IslaColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: IslaColors.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: IslaColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IslaColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: IslaColors.surfaceContainerHigh,
          style: GoogleFonts.inter(
            color: IslaColors.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: IslaColors.onSurfaceVariant,
          ),
          items: items
              .map(
                (s) => DropdownMenuItem(value: s, child: Text(s)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
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
