import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import 'gpa_calculator_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.borderRadiusLarge,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ahmad Student',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CB21088 • FKOM',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Year 3 • Semester 1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // GPA Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Academic Performance',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GPACalculatorScreen()),
                    );
                  },
                  child: Text(
                    'Calculate GPA',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _GradeCard(
                    title: 'Current GPA',
                    value: '3.65',
                    trend: '+0.12',
                    isPositive: true,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradeCard(
                    title: 'CGPA',
                    value: '3.52',
                    trend: '+0.05',
                    isPositive: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Study Statistics
            Text(
              'Study Statistics',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(isDark),
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: isDark ? [] : AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer_outlined,
                          value: '45h 30m',
                          label: 'Total Study Time',
                          color: AppTheme.primaryColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          value: '23',
                          label: 'Sessions',
                          color: AppTheme.warning,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.description_outlined,
                          value: '12',
                          label: 'Documents',
                          color: AppTheme.info,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.quiz_outlined,
                          value: '8',
                          label: 'Quizzes Taken',
                          color: AppTheme.success,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Study Time by Subject
            Text(
              'Study Time by Subject',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(isDark),
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: isDark ? [] : AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _SubjectProgressBar(
                    subject: 'BCS2033',
                    hours: 15,
                    maxHours: 20,
                    color: AppTheme.subjectColors[0],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _SubjectProgressBar(
                    subject: 'BCS3012',
                    hours: 12,
                    maxHours: 20,
                    color: AppTheme.subjectColors[1],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _SubjectProgressBar(
                    subject: 'BCS2042',
                    hours: 10,
                    maxHours: 20,
                    color: AppTheme.subjectColors[2],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _SubjectProgressBar(
                    subject: 'BCS4051',
                    hours: 8,
                    maxHours: 20,
                    color: AppTheme.subjectColors[3],
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Weekly Activity
            Text(
              'This Week',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(isDark),
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: isDark ? [] : AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DayActivity(
                          day: 'Mon', hours: 2, isToday: false, isDark: isDark),
                      _DayActivity(
                          day: 'Tue', hours: 3, isToday: false, isDark: isDark),
                      _DayActivity(
                          day: 'Wed',
                          hours: 1.5,
                          isToday: false,
                          isDark: isDark),
                      _DayActivity(
                          day: 'Thu', hours: 4, isToday: true, isDark: isDark),
                      _DayActivity(
                          day: 'Fri', hours: 0, isToday: false, isDark: isDark),
                      _DayActivity(
                          day: 'Sat', hours: 0, isToday: false, isDark: isDark),
                      _DayActivity(
                          day: 'Sun', hours: 0, isToday: false, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '10.5h',
                            style: AppTheme.headingMedium.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text('This Week', style: AppTheme.bodySmall),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.surfaceColor,
                      ),
                      Column(
                        children: [
                          Text(
                            '1.5h',
                            style: AppTheme.headingMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text('Daily Avg', style: AppTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.error),
                  foregroundColor: AppTheme.error,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositive;
  final bool isDark;

  const _GradeCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.getTextSecondary(isDark))),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isPositive ? AppTheme.success : AppTheme.error)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: isPositive ? AppTheme.success : AppTheme.error,
                    ),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.getCardColor(isDark) : color.withOpacity(0.1),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : [],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTheme.headingSmall.copyWith(color: color),
              ),
              Text(label,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.getTextSecondary(isDark))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectProgressBar extends StatelessWidget {
  final String subject;
  final double hours;
  final double maxHours;
  final Color color;
  final bool isDark;

  const _SubjectProgressBar({
    required this.subject,
    required this.hours,
    required this.maxHours,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subject,
                style: AppTheme.labelMedium
                    .copyWith(color: AppTheme.getTextPrimary(isDark))),
            Text(
              '${hours.toStringAsFixed(0)}h',
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: hours / maxHours,
          backgroundColor: isDark
              ? AppTheme.darkCard.withOpacity(0.3)
              : AppTheme.surfaceColor,
          valueColor: AlwaysStoppedAnimation(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 8,
        ),
      ],
    );
  }
}

class _DayActivity extends StatelessWidget {
  final String day;
  final double hours;
  final bool isToday;
  final bool isDark;

  const _DayActivity({
    required this.day,
    required this.hours,
    required this.isToday,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const maxHeight = 60.0;
    final barHeight = hours > 0 ? (hours / 5) * maxHeight : 4.0;

    return Column(
      children: [
        SizedBox(
          height: maxHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 24,
                height: barHeight,
                decoration: BoxDecoration(
                  color: hours > 0
                      ? (isToday
                          ? AppTheme.primaryColor
                          : AppTheme.primaryLight)
                      : (isDark
                          ? AppTheme.darkCard.withOpacity(0.3)
                          : AppTheme.surfaceColor),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: AppTheme.bodySmall.copyWith(
            color: isToday
                ? AppTheme.primaryColor
                : AppTheme.getTextSecondary(isDark),
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
