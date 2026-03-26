import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../documents/documents_screen.dart';
import '../planner/add_task_screen.dart';
import '../study_aids/study_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _currentTime;
  late String _greeting;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    setState(() {
      _currentTime = '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      if (hour < 12) {
        _greeting = 'Good Morning';
      } else if (hour < 17) {
        _greeting = 'Good Afternoon';
      } else {
        _greeting = 'Good Evening';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Live Clock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTime,
                        style: AppTheme.headingLarge.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_greeting, Student!',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                        onPressed: () => themeProvider.toggleTheme(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.getCardColor(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                        onPressed: () {},
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.getCardColor(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                        child: const Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Task Statistics Row (like MyStudyLife)
              Row(
                children: [
                  Expanded(
                    child: _TaskStatCard(
                      label: 'Pending Tasks',
                      count: '8',
                      subLabel: 'Last 7 days',
                      color: AppTheme.warning,
                      icon: Icons.pending_actions_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TaskStatCard(
                      label: 'Overdue Tasks',
                      count: '2',
                      subLabel: 'Last 7 days',
                      color: AppTheme.error,
                      icon: Icons.error_outline_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _TaskStatCard(
                      label: 'Tasks Completed',
                      count: '12',
                      subLabel: 'Last 7 days',
                      color: AppTheme.success,
                      icon: Icons.check_circle_outline_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TaskStatCard(
                      label: 'Your Streak',
                      count: '5',
                      subLabel: 'Last 7 days',
                      color: AppTheme.primaryColor,
                      icon: Icons.local_fire_department_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Today's Progress Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppTheme.borderRadiusLarge,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Focus Timer",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '25:00',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to start a focus session?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Start Focus Timer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Study Statistics
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(isDark),
                  borderRadius: AppTheme.borderRadiusLarge,
                  boxShadow: isDark ? [] : AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Study Time", 
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          '2h 30m',
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ProgressItem(
                          icon: Icons.description_outlined,
                          label: 'Documents',
                          value: '5',
                        ),
                        const SizedBox(width: 24),
                        _ProgressItem(
                          icon: Icons.quiz_outlined,
                          label: 'Quizzes',
                          value: '3',
                        ),
                        const SizedBox(width: 24),
                        _ProgressItem(
                          icon: Icons.task_alt_outlined,
                          label: 'Tasks',
                          value: '7',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions', 
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudyLibraryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('My Library'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.upload_file_rounded,
                      label: 'Upload\nDocument',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_task_rounded,
                      label: 'Add\nTask',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddTaskScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.timer_rounded,
                      label: 'Start\nTimer',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        // Navigate to timer (handled by bottom nav)
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Documents
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Documents', 
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'See All',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Document Cards
              _DocumentCard(
                title: 'Data Structures Notes',
                subject: 'BCS2033',
                date: '2 hours ago',
                color: AppTheme.subjectColors[0],
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                title: 'Software Engineering Ch.5',
                subject: 'BCS3012',
                date: 'Yesterday',
                color: AppTheme.subjectColors[1],
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                title: 'Database Design Slides',
                subject: 'BCS2042',
                date: '2 days ago',
                color: AppTheme.subjectColors[2],
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Upcoming Tasks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Tasks', 
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'See All',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _TaskCard(
                title: 'Assignment 2 - OOP',
                dueDate: 'Due Tomorrow',
                type: 'Assignment',
                isUrgent: true,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _TaskCard(
                title: 'Midterm Exam - Database',
                dueDate: 'Due in 3 days',
                type: 'Exam',
                isUrgent: false,
                isDark: isDark,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProgressItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subject;
  final String date;
  final Color color;
  final bool isDark;

  const _DocumentCard({
    required this.title,
    required this.subject,
    required this.date,
    required this.color,
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_rounded, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: AppTheme.bodySmall.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date, 
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded, 
            color: AppTheme.getTextLight(isDark),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String dueDate;
  final String type;
  final bool isUrgent;
  final bool isDark;

  const _TaskCard({
    required this.title,
    required this.dueDate,
    required this.type,
    required this.isUrgent,
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
        border: isUrgent
            ? Border.all(color: AppTheme.error.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: isUrgent ? AppTheme.error : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: isUrgent ? AppTheme.error : AppTheme.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dueDate,
                      style: AppTheme.bodySmall.copyWith(
                        color: isUrgent
                            ? AppTheme.error
                            : AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark 
                          ? AppTheme.getTextLight(isDark).withOpacity(0.1)
                          : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppTheme.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: false,
            onChanged: (value) {},
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _TaskStatCard extends StatelessWidget {
  final String label;
  final String count;
  final String subLabel;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _TaskStatCard({
    required this.label,
    required this.count,
    required this.subLabel,
    required this.color,
    required this.icon,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: AppTheme.headingLarge.copyWith(
              fontSize: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(isDark),
            ),
          ),
          Text(
            subLabel,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 10,
              color: AppTheme.getTextLight(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
