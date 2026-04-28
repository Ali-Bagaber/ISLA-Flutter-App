import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/document_service.dart';
import '../../services/gemini_study_service.dart';
import '../../services/gpa_service.dart';
import '../../services/task_service.dart';
import '../../models/user_profile.dart';
import '../../services/firebase_profile_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';
import 'gpa_calculator_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseProfileService _profileService = FirebaseProfileService();

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Color _subjectColor(String subject) {
    final index = subject.codeUnits.fold<int>(0, (sum, value) => sum + value) %
        AppTheme.subjectColors.length;
    return AppTheme.subjectColors[index];
  }

  String _normalizeSubjectLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Other Tasks';
    if (value.toLowerCase() == 'no subject') return 'Other Tasks';
    return value;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Map<String, _SessionChecklistStats> _groupSessionChecklistStats(
      List<Map<String, dynamic>> sessions) {
    final grouped = <String, _SessionChecklistStats>{};

    for (final session in sessions) {
      final subject = _normalizeSubjectLabel(
        (session['subject'] ?? '').toString(),
      );
      final done = _toInt(session['checklistDone']);
      final total = _toInt(session['checklistTotal']);

      final stats =
          grouped.putIfAbsent(subject, () => _SessionChecklistStats());
      stats.sessionCount += 1;
      stats.done += done;
      stats.total += total;
    }

    grouped.removeWhere((_, stats) => stats.sessionCount == 0);
    return grouped;
  }

  List<_WeekDayData> _buildWeekData(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final minutesByDay = <DateTime, int>{};

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      minutesByDay[day] = 0;
    }

    for (final session in sessions) {
      final timestamp = _toDateTime(session['timestamp']);
      if (timestamp == null) continue;

      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (!minutesByDay.containsKey(day)) continue;

      final focusMinutes = session['focusMinutes'];
      final minutes = focusMinutes is int
          ? focusMinutes
          : (focusMinutes is num ? focusMinutes.toInt() : 0);

      minutesByDay[day] = (minutesByDay[day] ?? 0) + minutes;
    }

    return minutesByDay.entries.map((entry) {
      final day = entry.key;
      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return _WeekDayData(
        label: labels[day.weekday - 1],
        hours: entry.value / 60,
        isToday: day == today,
      );
    }).toList();
  }

  Future<void> _openEditProfile(UserProfile profile) async {
    final nameController = TextEditingController(text: profile.name);
    final studentIdController = TextEditingController(text: profile.studentId);
    final facultyController = TextEditingController(text: profile.faculty);
    final yearController = TextEditingController(
        text: profile.year == 0 ? '' : profile.year.toString());
    final semesterController = TextEditingController(
        text: profile.semester == 0 ? '' : profile.semester.toString());

    Uint8List? pickedBytes;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickPhoto() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              withData: true,
            );
            if (result != null && result.files.single.bytes != null) {
              setDialogState(() => pickedBytes = result.files.single.bytes!);
            }
          }

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // â”€â”€ Profile photo picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  GestureDetector(
                    onTap: pickPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pickedBytes != null
                              ? Image.memory(pickedBytes!,
                                  width: 88, height: 88, fit: BoxFit.cover)
                              : profile.photoUrl.isNotEmpty
                                  ? Image.network(
                                      profile.photoUrl,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 44,
                                        color: AppTheme.primaryColor,
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      size: 44, color: AppTheme.primaryColor),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // â”€â”€ Text fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: studentIdController,
                    decoration: const InputDecoration(labelText: 'Student ID'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: facultyController,
                    decoration: const InputDecoration(labelText: 'Faculty'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: semesterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Semester'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          String photoUrl = profile.photoUrl;
                          if (pickedBytes != null) {
                            final uploaded = await _profileService
                                .uploadProfilePhoto(pickedBytes!);
                            if (uploaded == null) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Photo upload failed. Check your connection and try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              setDialogState(() => isSaving = false);
                              return;
                            }
                            photoUrl = uploaded;
                          }
                          final updated = profile.copyWith(
                            name: nameController.text.trim(),
                            studentId: studentIdController.text.trim(),
                            faculty: facultyController.text.trim(),
                            year: int.tryParse(yearController.text.trim()) ??
                                profile.year,
                            semester:
                                int.tryParse(semesterController.text.trim()) ??
                                    profile.semester,
                            photoUrl: photoUrl,
                          );
                          await _profileService.saveProfile(updated);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Profile updated successfully'),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error saving profile: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to log out. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openProfileActions() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final isDark = Provider.of<ThemeProvider>(sheetContext).isDarkMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(
                    'Log out',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'logout'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == 'logout') {
      await _confirmAndLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      body: SafeArea(
        child: Container(
          decoration: AppTheme.getBackgroundDecoration(isDark),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IslaLogo(),
                    const Spacer(),
                    IslaProfileAvatar(onTap: _openProfileActions),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<UserProfile>(
                  stream: _profileService.watchProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data ?? UserProfile.initial();
                    final displayName = profile.name.trim().isEmpty
                        ? 'Set your profile name'
                        : profile.name;
                    final details = <String>[];
                    if (profile.studentId.trim().isNotEmpty) {
                      details.add(profile.studentId.trim());
                    }
                    if (profile.faculty.trim().isNotEmpty) {
                      details.add(profile.faculty.trim());
                    }
                    final profileDetails = details.isEmpty
                        ? 'No profile details yet'
                        : details.join(' â€¢ ');
                    final hasYearSemester =
                        profile.year > 0 && profile.semester > 0;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppTheme.borderRadiusLarge,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: profile.photoUrl.isNotEmpty
                                ? Image.network(
                                    profile.photoUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
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
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profileDetails,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                  ),
                                ),
                                if (hasYearSemester) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Year ${profile.year} â€¢ Semester ${profile.semester}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openEditProfile(profile),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

                StreamBuilder<Map<String, dynamic>?>(
                  stream: GpaService.watchGpaRecord(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final record = snapshot.data;
                    if (record == null) {
                      return _EmptyDashboardSection(
                        icon: Icons.school_outlined,
                        message:
                            'No GPA/CGPA data yet. Use Calculate GPA to start tracking your grades.',
                        isDark: isDark,
                      );
                    }

                    final gpa = (record['gpa'] as num?)?.toDouble() ?? 0.0;
                    final totalCredits =
                        (record['totalCredits'] as num?)?.toInt() ?? 0;
                    final courseCount =
                        (record['courseCount'] as num?)?.toInt() ?? 0;
                    final standing = gpa >= 3.5
                        ? "Dean's List"
                        : gpa >= 3.0
                            ? 'Good Standing'
                            : gpa >= 2.0
                                ? 'Satisfactory'
                                : 'Needs Improvement';
                    final gradientColor = gpa >= 3.5
                        ? AppTheme.success
                        : gpa >= 3.0
                            ? AppTheme.primaryColor
                            : gpa >= 2.0
                                ? AppTheme.warning
                                : AppTheme.error;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradientColor,
                            gradientColor.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppTheme.borderRadiusLarge,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Current GPA',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            gpa.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              standing,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GpaStatChip(
                                label: 'Total Credits',
                                value: '$totalCredits',
                              ),
                              const SizedBox(width: 16),
                              _GpaStatChip(
                                label: 'Courses',
                                value: '$courseCount',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
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

                FutureBuilder<Map<String, int>>(
                  future: _profileService.loadStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ??
                        {
                          'minutes': 0,
                          'sessions': 0,
                          'documents': 0,
                          'quizzes': 0,
                        };

                    return Container(
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
                                  value: '${stats['minutes'] ?? 0}m',
                                  label: 'Total Study Time',
                                  color: AppTheme.primaryColor,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.local_fire_department_rounded,
                                  value: '${stats['sessions'] ?? 0}',
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
                                  value: '${stats['documents'] ?? 0}',
                                  label: 'Documents',
                                  color: AppTheme.info,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.quiz_outlined,
                                  value: '${stats['quizzes'] ?? 0}',
                                  label: 'Quizzes Taken',
                                  color: AppTheme.success,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // â”€â”€ Marks by Course â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Text(
                  'Marks by Course',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: DocumentService.watchCourses(),
                  builder: (context, coursesSnap) {
                    final courses = coursesSnap.data ?? [];
                    final courseNames = courses
                        .map((c) => (c['name'] as String? ?? '').trim())
                        .where((n) => n.isNotEmpty)
                        .toList();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: DocumentService.watchMarks(),
                      builder: (context, marksSnap) {
                        final marks = marksSnap.data ?? [];

                        if (courseNames.isEmpty && marks.isEmpty) {
                          return _EmptyDashboardSection(
                            icon: Icons.bar_chart_rounded,
                            message:
                                'No courses yet. Add courses in GPA Calculator to track marks here.',
                            isDark: isDark,
                          );
                        }

                        // Group marks by course
                        final grouped = <String, List<Map<String, dynamic>>>{};
                        for (final n in courseNames) {
                          grouped.putIfAbsent(n, () => []);
                        }
                        for (final m in marks) {
                          final sub = (m['subject'] as String? ?? '').trim();
                          grouped.putIfAbsent(sub, () => []).add(m);
                        }
                        final subjects = grouped.keys.toList()..sort();

                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(isDark),
                            borderRadius: AppTheme.borderRadiusLarge,
                            boxShadow: isDark ? [] : AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < subjects.length; i++) ...[
                                _DashboardMarksGroup(
                                  subject: subjects[i],
                                  marks: grouped[subjects[i]]!,
                                  isDark: isDark,
                                  onAdd: () => _showAddMarkDialog(
                                    context,
                                    preselectedSubject: subjects[i],
                                    courseNames: courseNames,
                                    isDark: isDark,
                                  ),
                                  onDelete: (id) =>
                                      DocumentService.deleteMark(id),
                                ),
                                if (i < subjects.length - 1)
                                  Divider(
                                    height: 1,
                                    color: AppTheme.getSurfaceColor(isDark),
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Tasks by Subject / Other
                Text(
                  'Tasks by Subject / Other',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: TaskService.watchTasks(),
                  builder: (context, snapshot) {
                    final tasks = snapshot.data ?? [];

                    if (tasks.isEmpty) {
                      return _EmptyDashboardSection(
                        icon: Icons.task_alt_outlined,
                        message:
                            'No tasks yet. Add tasks to see subject and other task groups.',
                        isDark: isDark,
                      );
                    }

                    final grouped = <String, List<Map<String, dynamic>>>{};
                    for (final task in tasks) {
                      final subject = _normalizeSubjectLabel(
                        (task['subject'] ?? '').toString(),
                      );
                      grouped.putIfAbsent(subject, () => []).add(task);
                    }

                    final subjects = grouped.keys.toList()..sort();
                    if (subjects.isEmpty) {
                      return _EmptyDashboardSection(
                        icon: Icons.task_alt_outlined,
                        message: 'No tasks available yet in any group.',
                        isDark: isDark,
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(isDark),
                        borderRadius: AppTheme.borderRadiusLarge,
                        boxShadow: isDark ? [] : AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < subjects.length; i++) ...[
                            _SubjectChecklistGroup(
                              subject: subjects[i],
                              color: _subjectColor(subjects[i]),
                              isDark: isDark,
                              items: grouped[subjects[i]]!
                                  .take(5)
                                  .map(
                                    (task) => _ChecklistPreviewItem(
                                      (task['title'] ?? 'Untitled task')
                                          .toString(),
                                      task['completed'] == true,
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (i != subjects.length - 1)
                              const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Session Checklist by Subject
                Text(
                  'Checklist by Subject (Session)',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: GeminiStudyService.watchSessions(),
                  builder: (context, snapshot) {
                    final sessions = snapshot.data ?? [];
                    if (sessions.isEmpty) {
                      return _EmptyDashboardSection(
                        icon: Icons.fact_check_outlined,
                        message:
                            'No session data yet. Complete a session from Session tab.',
                        isDark: isDark,
                      );
                    }

                    final grouped = _groupSessionChecklistStats(sessions);
                    if (grouped.isEmpty) {
                      return _EmptyDashboardSection(
                        icon: Icons.fact_check_outlined,
                        message:
                            'No session checklist snapshots yet. Generate checklist in Session tab first.',
                        isDark: isDark,
                      );
                    }

                    final subjects = grouped.keys.toList()..sort();

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(isDark),
                        borderRadius: AppTheme.borderRadiusLarge,
                        boxShadow: isDark ? [] : AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < subjects.length; i++) ...[
                            _SessionChecklistSubjectRow(
                              subject: subjects[i],
                              color: _subjectColor(subjects[i]),
                              isDark: isDark,
                              done: grouped[subjects[i]]!.done,
                              total: grouped[subjects[i]]!.total,
                              sessionCount: grouped[subjects[i]]!.sessionCount,
                            ),
                            if (i != subjects.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    );
                  },
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

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: GeminiStudyService.watchSessions(),
                  builder: (context, snapshot) {
                    final weekData = _buildWeekData(snapshot.data ?? []);
                    final totalHours = weekData.fold<double>(
                      0,
                      (sum, day) => sum + day.hours,
                    );
                    final dailyAvg = totalHours / 7;

                    return Container(
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
                            children: weekData
                                .map(
                                  (day) => _DayActivity(
                                    day: day.label,
                                    hours: day.hours,
                                    isToday: day.isToday,
                                    isDark: isDark,
                                  ),
                                )
                                .toList(),
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
                                    '${totalHours.toStringAsFixed(1)}h',
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
                                color: AppTheme.getSurfaceColor(isDark),
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${dailyAvg.toStringAsFixed(1)}h',
                                    style: AppTheme.headingMedium.copyWith(
                                      color: AppTheme.getTextSecondary(isDark),
                                    ),
                                  ),
                                  Text('Daily Avg', style: AppTheme.bodySmall),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Refresh Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryColor),
                      foregroundColor: AppTheme.primaryColor,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh Dashboard'),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddMarkDialog(
    BuildContext context, {
    String? preselectedSubject,
    List<String> courseNames = const [],
    required bool isDark,
  }) async {
    String selectedSubject =
        preselectedSubject ?? (courseNames.isNotEmpty ? courseNames.first : '');
    final nameCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    String selectedType = 'Quiz';

    const types = [
      'Quiz',
      'Assignment',
      'Lab',
      'Midterm',
      'Final',
      'Project',
      'Other'
    ];
    // Suggested weights for common types (out of 100)
    const typeWeights = {
      'Quiz': '5',
      'Assignment': '20',
      'Lab': '10',
      'Midterm': '30',
      'Final': '40',
      'Project': '25',
      'Other': '10',
    };

    weightCtrl.text = typeWeights[selectedType] ?? '10';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Assessment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Course
                if (courseNames.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: courseNames.contains(selectedSubject)
                        ? selectedSubject
                        : courseNames.first,
                    decoration: const InputDecoration(labelText: 'Course'),
                    items: courseNames
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => set(() => selectedSubject = v ?? ''),
                  )
                else
                  TextField(
                    decoration:
                        const InputDecoration(labelText: 'Course / Subject'),
                    onChanged: (v) => selectedSubject = v.trim(),
                  ),
                const SizedBox(height: 12),
                // Type
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration:
                      const InputDecoration(labelText: 'Assessment Type'),
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    set(() {
                      selectedType = v ?? 'Quiz';
                      weightCtrl.text = typeWeights[selectedType] ?? '10';
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Weight out of 100
                TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => set(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Worth (out of 100 total)',
                    hintText: 'e.g. 20 means this is 20% of your grade',
                  ),
                ),
                const SizedBox(height: 12),
                // Name (optional)
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name (optional)',
                    hintText: 'e.g. $selectedType 1',
                  ),
                ),
                const SizedBox(height: 12),
                // Score out of worth
                TextField(
                  controller: scoreCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Your Score (out of ${weightCtrl.text.isEmpty ? '?' : weightCtrl.text})',
                    hintText: 'How many marks you got',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final rawName = nameCtrl.text.trim();
                final score = double.tryParse(scoreCtrl.text.trim());
                final weight = double.tryParse(weightCtrl.text.trim()) ?? 0;
                if (selectedSubject.isEmpty || score == null || weight <= 0)
                  return;
                final name = rawName.isEmpty ? selectedType : rawName;
                await DocumentService.addMark(
                  subject: selectedSubject,
                  name: name,
                  type: selectedType,
                  score: score,
                  maxScore: weight,
                  weight: weight,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    scoreCtrl.dispose();
    weightCtrl.dispose();
  }
}

class _GpaStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _GpaStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
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
        color: isDark
            ? AppTheme.getCardColor(isDark)
            : color.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : [],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headingSmall.copyWith(
                    color: color,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.getTextSecondary(isDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistPreviewItem {
  final String title;
  final bool completed;

  const _ChecklistPreviewItem(this.title, this.completed);
}

class _SessionChecklistStats {
  int sessionCount;
  int done;
  int total;

  _SessionChecklistStats()
      : sessionCount = 0,
        done = 0,
        total = 0;
}

class _WeekDayData {
  final String label;
  final double hours;
  final bool isToday;

  const _WeekDayData({
    required this.label,
    required this.hours,
    required this.isToday,
  });
}

class _EmptyDashboardSection extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptyDashboardSection({
    required this.icon,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.getTextSecondary(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.getTextSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChecklistGroup extends StatelessWidget {
  final String subject;
  final Color color;
  final bool isDark;
  final List<_ChecklistPreviewItem> items;

  const _SubjectChecklistGroup({
    required this.subject,
    required this.color,
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = items.where((item) => item.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subject,
                style: AppTheme.labelMedium
                    .copyWith(color: AppTheme.getTextPrimary(isDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$completedCount/${items.length} done',
                style: AppTheme.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  item.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: item.completed
                      ? color
                      : AppTheme.getTextSecondary(isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getTextSecondary(isDark),
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionChecklistSubjectRow extends StatelessWidget {
  final String subject;
  final Color color;
  final bool isDark;
  final int done;
  final int total;
  final int sessionCount;

  const _SessionChecklistSubjectRow({
    required this.subject,
    required this.color,
    required this.isDark,
    required this.done,
    required this.total,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final ratio = (done / safeTotal).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: AppTheme.labelMedium
                  .copyWith(color: AppTheme.getTextPrimary(isDark)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$done/$total done',
                style: AppTheme.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: isDark
              ? AppTheme.darkCard.withValues(alpha: 0.35)
              : AppTheme.getSurfaceColor(isDark),
          valueColor: AlwaysStoppedAnimation(color),
        ),
        const SizedBox(height: 6),
        Text(
          '$sessionCount session${sessionCount == 1 ? '' : 's'}',
          style: AppTheme.bodySmall
              .copyWith(color: AppTheme.getTextSecondary(isDark)),
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
    final barHeight = hours > 0
        ? ((hours / 5) * maxHeight).clamp(4.0, maxHeight).toDouble()
        : 4.0;

    return Column(
      children: [
        SizedBox(
          height: maxHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 24,
              height: barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: hours > 0
                      ? (isToday
                          ? AppTheme.primaryColor
                          : AppTheme.primaryLight)
                      : (isDark
                          ? AppTheme.darkCard.withValues(alpha: 0.3)
                          : AppTheme.getSurfaceColor(isDark)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
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

// ─── Dashboard Marks Group ────────────────────────────────────────────────────

class _DashboardMarksGroup extends StatelessWidget {
  final String subject;
  final List<Map<String, dynamic>> marks;
  final bool isDark;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;

  const _DashboardMarksGroup({
    required this.subject,
    required this.marks,
    required this.isDark,
    required this.onAdd,
    required this.onDelete,
  });

  // Total contribution out of 100 using weight-based formula
  double get _totalContribution {
    if (marks.isEmpty) return 0;
    return marks.fold<double>(0, (sum, m) {
      final weight = (m['weight'] as num? ?? 0).toDouble();
      final score = (m['score'] as num? ?? 0).toDouble();
      final max = (m['maxScore'] as num? ?? 0).toDouble();
      if (weight > 0 && max > 0) return sum + (score / max) * weight;
      final contrib =
          (m['contribution'] as num? ?? m['percentage'] as num? ?? 0)
              .toDouble();
      return sum + contrib;
    });
  }

  double get _totalWeight {
    return marks.fold<double>(
        0, (s, m) => s + ((m['weight'] as num? ?? 0).toDouble()));
  }

  Color _gradeColor(double pct) {
    if (pct >= 80) return const Color(0xFF10B981);
    if (pct >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalContribution;
    final totalWeight = _totalWeight;
    final color =
        _gradeColor(totalWeight > 0 ? (total / totalWeight) * 100 : total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.getTextPrimary(isDark),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (marks.isNotEmpty)
                      Text(
                        '${marks.length} assessment${marks.length == 1 ? "" : "s"}  \u2022  '
                        '${total.toStringAsFixed(1)} / 100',
                        style: AppTheme.bodySmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.primaryColor, size: 22),
                tooltip: 'Add assessment',
                onPressed: onAdd,
              ),
            ],
          ),
          if (marks.isNotEmpty) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (total / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.getSurfaceColor(isDark),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total.toStringAsFixed(1)} marks earned',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.getTextSecondary(isDark)),
                ),
                Text(
                  '${(100 - total).clamp(0.0, 100.0).toStringAsFixed(1)} remaining',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.getTextSecondary(isDark)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...marks.map((m) {
              final weight = (m['weight'] as num? ?? 0).toDouble();
              final score = (m['score'] as num? ?? 0).toDouble();
              final max = (m['maxScore'] as num? ?? 0).toDouble();
              final contrib = weight > 0 && max > 0
                  ? (score / max) * weight
                  : (m['contribution'] as num? ?? m['percentage'] as num? ?? 0)
                      .toDouble();
              final rowColor =
                  _gradeColor(weight > 0 ? (contrib / weight) * 100 : contrib);
              final name = (m['name'] as String? ?? '').trim();
              final type = (m['type'] as String? ?? '');
              final label =
                  name.isNotEmpty && name != type ? '$name \u00b7 $type' : type;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: rowColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      weight > 0
                          ? '${contrib.toStringAsFixed(1)} / $weight'
                          : '${score.toStringAsFixed(1)} / $max',
                      style: AppTheme.bodySmall.copyWith(
                        color: rowColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onDelete(m['id'] as String? ?? ''),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: AppTheme.getTextSecondary(isDark)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
