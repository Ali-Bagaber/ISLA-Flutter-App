import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/gpa_service.dart';
import '../../services/user_settings_service.dart';
import '../../services/nav_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/isla_logo.dart';
import '../../widgets/notifications_inbox_sheet.dart';
import '../../widgets/page_entrance.dart';
import 'gpa_calculator_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static FirebaseFirestore? get _db =>
      Firebase.apps.isEmpty ? null : FirebaseFirestore.instance;

  static Stream<List<Map<String, dynamic>>> _coursesStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value([]);
    return db
        .collection('courses')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static double _computeGpa(List<Map<String, dynamic>> courses) {
    // Grade → GPA point mapping (4.0 scale)
    const gradePoints = {
      'A+': 4.0,
      'A': 4.0,
      'A-': 3.7,
      'B+': 3.3,
      'B': 3.0,
      'B-': 2.7,
      'C+': 2.3,
      'C': 2.0,
      'C-': 1.7,
      'D+': 1.3,
      'D': 1.0,
      'F': 0.0,
    };
    double totalPoints = 0;
    int totalCredits = 0;
    for (final c in courses) {
      final grade = ((c['grade'] ?? '') as String).trim().toUpperCase();
      final credits = (c['credits'] as num? ?? 3).toInt();
      final points = gradePoints[grade];
      if (points != null && credits > 0) {
        totalPoints += points * credits;
        totalCredits += credits;
      }
    }
    if (totalCredits == 0) return 0.0;
    return double.parse((totalPoints / totalCredits).toStringAsFixed(2));
  }

  /// Single Firestore listener for all session-derived metrics.
  /// Replaces the four separate sessions queries that used to run in parallel.
  static Stream<Map<String, dynamic>> _allSessionMetrics() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value({});
    return db
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      int totalMins = 0;
      int count = 0;
      final subjectMinutes = <String, int>{};
      final studyDates = <DateTime>{};

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final mondayStart = DateTime(monday.year, monday.month, monday.day);
      final weekMins = List.filled(7, 0);

      for (final doc in snap.docs) {
        final data = doc.data();
        final mins = (data['focusMinutes'] as num? ?? 0).toInt();
        totalMins += mins;
        count++;

        final subject = (data['subject'] ?? 'Other').toString();
        subjectMinutes[subject] = (subjectMinutes[subject] ?? 0) + mins;

        final ts = data['timestamp'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date != null) {
          studyDates.add(DateTime(date.year, date.month, date.day));
          final day = DateTime(date.year, date.month, date.day);
          if (!day.isBefore(mondayStart)) {
            final idx = date.weekday - 1;
            if (idx >= 0 && idx <= 6) weekMins[idx] += mins;
          }
        }
      }

      // Zero out future days so chart looks honest
      for (var i = now.weekday; i < 7; i++) weekMins[i] = 0;

      // Streak
      var streak = 0;
      if (studyDates.isNotEmpty) {
        var check = DateTime(now.year, now.month, now.day);
        if (!studyDates.contains(check)) {
          check = check.subtract(const Duration(days: 1));
        }
        while (studyDates.contains(check)) {
          streak++;
          check = check.subtract(const Duration(days: 1));
        }
      }

      return <String, dynamic>{
        'totalStudyTime': totalMins,
        'sessionCount': count,
        'subjectMinutes': subjectMinutes,
        'weeklyHours': weekMins.map((m) => m / 60.0).toList(),
        'streak': streak,
      };
    });
  }

  static Stream<Map<String, dynamic>> _profileStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value({});
    return db
        .collection('profiles')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? s.data()! : <String, dynamic>{});
  }

  static Stream<int> _completedTasksStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value(0);
    return db
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .where('completed', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Count of AI-generated items: summaries, flashcards, quizzes.
  static Stream<Map<String, int>> _aiStatsStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value({'summaries': 0, 'flashcards': 0, 'quizzes': 0});

    Stream<int> count(String col) => db
        .collection(col)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.length);

    return count('summaries').asyncExpand((s) =>
        count('flashcards').asyncExpand((f) =>
            count('quiz_aids').map((q) => {'summaries': s, 'flashcards': f, 'quizzes': q})));
  }

  String _formatMinutes(int mins) {
    if (mins >= 60) return '${(mins / 60).toStringAsFixed(1)}h';
    return '${mins}m';
  }

  void _showNotificationsSheet(BuildContext context) =>
      showIslaNotificationsInbox(context);

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<NavController>().goTo(6);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(ctx);
                await AuthService.signOut();
                if (context.mounted) context.goNamed('splash');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? IslaColors.background : const Color(0xFFF4FBFE);
    final onSurfaceMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Standard AppBar (matches Tasks page) ──────────────────────
            Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: bg),
              child: Row(
                children: [
                  const IslaLogo(markSize: 28, textSize: 17),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showNotificationsSheet(context),
                    icon: Icon(Icons.notifications_outlined,
                        color: onSurfaceMute, size: 22),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 4),
                  IslaProfileAvatar(
                    radius: 17,
                    onTap: () => _showProfileSheet(context),
                  ),
                ],
              ),
            ),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: PageEntrance(
                child: StreamBuilder<Map<String, dynamic>>(
                stream: _allSessionMetrics(),
                builder: (context, analyticsSnap) {
                  final analytics = analyticsSnap.data ?? {};
                  final totalMins = (analytics['totalStudyTime'] as num? ?? 0).toInt();
                  final sessionCount = (analytics['sessionCount'] as num? ?? 0).toInt();
                  final sessionStreak = analytics['streak'] as int? ?? 0;
                  final weeklyHours = (analytics['weeklyHours'] as List?)
                      ?.map((e) => (e as num).toDouble()).toList()
                      ?? List.filled(7, 0.0);
                  final subjectMinutesMap = (analytics['subjectMinutes'] as Map?)
                      ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
                      ?? <String, int>{};

                  return StreamBuilder<int>(
                    stream: _completedTasksStream(),
                    builder: (context, tasksSnap) {
                      final tasksDone = tasksSnap.data ?? 0;

                      return StreamBuilder<Map<String, dynamic>>(
                        stream: _profileStream(),
                        builder: (context, profileSnap) {
                          final profile = profileSnap.data ?? {};
                          final name = (profile['name'] ??
                                  profile['displayName'] ??
                                  FirebaseAuth
                                      .instance.currentUser?.displayName ??
                                  'Student')
                              .toString();

                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _coursesStream(),
                            builder: (context, coursesSnap) {
                              final courses = coursesSnap.data ?? [];
                              _computeGpa(courses); // kept for Marks section usage
                              final subjectMap = subjectMinutesMap;
                              final topSubjects = subjectMap.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value));
                              final maxMins = topSubjects.isEmpty
                                  ? 1
                                  : topSubjects.first.value.clamp(1, 99999);

                              return SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 18, 20, 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Text(
                                            'Analytics',
                                            style: GoogleFonts.manrope(
                                              color: isDark
                                                  ? IslaColors.onSurface
                                                  : const Color(0xFF0F1A1F),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 52,
                                              letterSpacing: -1.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Center(
                                          child: Text(
                                            'INSIGHTS & PROGRESS',
                                            style: GoogleFonts.manrope(
                                              color: isDark
                                                  ? IslaColors.onSurfaceVariant
                                                  : const Color(0xFF5A6770),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11,
                                              letterSpacing: 3.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Profile banner
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF111415)
                                                : const Color(0xFFEAF2F6),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: isDark
                                                    ? IslaColors.outlineVariant
                                                    : const Color(0xFFD4DEE4)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 54,
                                                height: 54,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient:
                                                      IslaColors.cyanToBlue,
                                                ),
                                                child: const Icon(Icons.person_rounded,
                                                    color: IslaColors
                                                        .onPrimaryContainer),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style:
                                                          GoogleFonts.manrope(
                                                        color: isDark
                                                            ? IslaColors
                                                                .onSurface
                                                            : const Color(
                                                                0xFF0F1A1F),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    Text(
                                                      sessionCount > 0
                                                          ? '$sessionCount study sessions completed'
                                                          : 'Start a focus session to track progress',
                                                      style: GoogleFonts.inter(
                                                        color: isDark
                                                            ? IslaColors
                                                                .onSurfaceVariant
                                                            : const Color(
                                                                0xFF5A6770),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        StreamBuilder<Map<String, int>>(
                                          stream: UserSettingsService.watchXp(),
                                          builder: (context, xpSnap) {
                                            final xp = xpSnap.data?['xp'] ?? 0;
                                            final level = UserSettingsService.levelFromXp(xp);
                                            final xpThisLevel = UserSettingsService.xpForLevel(level);
                                            final xpNextLevel = UserSettingsService.xpForLevel(level + 1);
                                            final progress = xpNextLevel > xpThisLevel
                                                ? ((xp - xpThisLevel) / (xpNextLevel - xpThisLevel)).clamp(0.0, 1.0)
                                                : 1.0;
                                            return Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isDark
                                                      ? [const Color(0xFF0D2233), const Color(0xFF0A1A2A)]
                                                      : [const Color(0xFFE0F4FF), const Color(0xFFD0EAF8)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF00C2D4).withValues(alpha: 0.3)
                                                      : const Color(0xFF00C2D4).withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00C2D4).withValues(alpha: 0.15),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: const Color(0xFF00C2D4), width: 2),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '$level',
                                                        style: GoogleFonts.manrope(
                                                          color: const Color(0xFF00C2D4),
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Level $level',
                                                              style: GoogleFonts.manrope(
                                                                color: isDark ? Colors.white : const Color(0xFF0F1A1F),
                                                                fontWeight: FontWeight.w700,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Text(
                                                              '$xp / $xpNextLevel XP',
                                                              style: GoogleFonts.inter(
                                                                color: const Color(0xFF00C2D4),
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: LinearProgressIndicator(
                                                            value: progress,
                                                            minHeight: 7,
                                                            backgroundColor: isDark
                                                                ? Colors.white.withValues(alpha: 0.08)
                                                                : Colors.black.withValues(alpha: 0.08),
                                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                                              Color(0xFF00C2D4),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          'Sessions · Tasks · Quizzes earn XP',
                                                          style: GoogleFonts.inter(
                                                            color: isDark
                                                                ? Colors.white.withValues(alpha: 0.4)
                                                                : const Color(0xFF5A6770),
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        GridView.count(
                                          crossAxisCount: 2,
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: 1.22,
                                          children: [
                                            _StatCard(
                                              icon: Icons.timer_rounded,
                                              label: 'Focus Hours',
                                              value: totalMins >= 60
                                                  ? '${(totalMins / 60).toStringAsFixed(1)}h'
                                                  : '${totalMins}m',
                                              change: 'All time',
                                              positive: true,
                                            ),
                                            _StatCard(
                                              icon: Icons.task_alt_rounded,
                                              label: 'Completed Tasks',
                                              value: '$tasksDone',
                                              change: 'All time',
                                              positive: true,
                                            ),
                                            _StatCard(
                                              icon: Icons.radio_button_checked_rounded,
                                              label: 'Pomodoro Sessions',
                                              value: '$sessionCount',
                                              change: 'All time',
                                              positive: true,
                                            ),
                                            _StatCard(
                                              icon: Icons.local_fire_department_rounded,
                                              label: 'Current Streak',
                                              value: sessionStreak > 0 ? '$sessionStreak days' : '\u2014',
                                              change: sessionStreak > 0 ? 'Keep it up! \ud83d\udd25' : 'Start your streak',
                                              positive: sessionStreak > 0,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _CgpaCard(isDark: isDark),
                                        const SizedBox(height: 18),
                                        _SectionLabel(label: 'Weekly Focus', isDark: isDark),
                                        const SizedBox(height: 10),
                                        _WeeklyBarChart(
                                          weeklyHours: weeklyHours,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 18),
                                        if (subjectMap.isNotEmpty) ...[
                                          // Chart card is self-titled, so no
                                          // outer section label (avoids the
                                          // duplicate "Focus Distribution").
                                          _FocusDonutChart(subjectMap: subjectMap, isDark: isDark),
                                          const SizedBox(height: 18),
                                        ],
                                        const SizedBox(height: 14),
                                        // Subject study time breakdown
                                        if (topSubjects.isNotEmpty) ...[
                                          Text(
                                            'Study Time by Subject',
                                            style: GoogleFonts.manrope(
                                              color: isDark
                                                  ? IslaColors.onSurface
                                                  : const Color(0xFF0F1A1F),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF111415)
                                                  : const Color(0xFFEAF2F6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Builder(builder: (_) {
                                              const palette = [
                                                Color(0xFF00C2D4),
                                                Color(0xFF8B5CF6),
                                                Color(0xFF10B981),
                                                Color(0xFFF59E0B),
                                                Color(0xFFEF4444),
                                              ];
                                              final entries = topSubjects.take(5).toList();
                                              return Column(
                                                children: List.generate(
                                                  entries.length,
                                                  (i) => Padding(
                                                    padding: const EdgeInsets.only(bottom: 10),
                                                    child: _SubjectRow(
                                                      subject: entries[i].key,
                                                      progress: entries[i].value / maxMins,
                                                      label: _formatMinutes(entries[i].value),
                                                      color: palette[i % palette.length],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ] else ...[
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF111415)
                                                  : const Color(0xFFEAF2F6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Complete focus sessions to see subject breakdown',
                                                style: GoogleFonts.inter(
                                                    color: isDark
                                                        ? IslaColors
                                                            .onSurfaceVariant
                                                        : const Color(
                                                            0xFF5A6770),
                                                    fontSize: 13),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        // ── AI Tools stats ──────────────────────
                                        StreamBuilder<Map<String, int>>(
                                          stream: _aiStatsStream(),
                                          builder: (context, aiSnap) {
                                            final stats = aiSnap.data ?? {};
                                            final s = stats['summaries'] ?? 0;
                                            final f = stats['flashcards'] ?? 0;
                                            final q = stats['quizzes'] ?? 0;
                                            if (s + f + q == 0) return const SizedBox.shrink();
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _SectionLabel(label: 'AI Tools Used', isDark: isDark),
                                                const SizedBox(height: 10),
                                                _AiStatsRow(
                                                  summaries: s,
                                                  flashcards: f,
                                                  quizzes: q,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 14),
                                              ],
                                            );
                                          },
                                        ),
                                        // ── Marks section ──────────────────────────
                                        const _MarksSection(),
                                      ],
                                    ),
                                  );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              ),
            ),
            // close Expanded(child: StreamBuilder)
          ],
          // close Column children
        ),
        // close SafeArea
      ),
    );
    // close Scaffold
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String change;
  final bool positive;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final cardBg = isDark ? const Color(0xFF111415) : const Color(0xFFFFFFFF);
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final onMute = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final changeColor = positive ? const Color(0xFF4ADE80) : const Color(0xFFFF8A80);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: primary, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.inter(
              color: onMute,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: GoogleFonts.inter(
              color: changeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F),
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<double> weeklyHours;
  final bool isDark;

  const _WeeklyBarChart({required this.weeklyHours, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cyan     = isDark ? const Color(0xFF00C2D4) : const Color(0xFF007E90);
    final cardBg   = isDark ? const Color(0xFF080F14) : Colors.white;
    final border   = isDark ? const Color(0xFF162028) : const Color(0xFFDCEDF5);
    final onMute   = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final trackCol = isDark ? const Color(0xFF0E1D26) : const Color(0xFFF0F7FA);

    const dayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const dayShort  = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = weeklyHours.length == 7
        ? weeklyHours.map((h) => h.clamp(0.0, 24.0)).toList()
        : List.filled(7, 0.0);
    final hasData    = values.any((v) => v > 0);
    final maxVal     = hasData ? values.reduce((a, b) => a > b ? a : b) : 0.0;
    final maxY       = hasData ? (maxVal * 1.35).clamp(1.0, 24.0) : 3.0;
    final todayIdx   = DateTime.now().weekday - 1;
    final totalHrs   = values.fold(0.0, (a, b) => a + b);
    final activeDays = values.where((v) => v > 0).length;
    final bestIdx    = hasData
        ? values.indexOf(values.reduce((a, b) => a > b ? a : b))
        : -1;

    // Subtle glow shadow for today bar — we composite it via Stack with a
    // blurred, tinted container behind the chart.
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Focus',
                        style: GoogleFonts.manrope(
                          color: onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This week · Mon–Sun',
                        style: GoogleFonts.inter(
                          color: onMute,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cyan.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cyan.withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Text(
                    hasData ? '${totalHrs.toStringAsFixed(1)}h total' : 'No data yet',
                    style: GoogleFonts.manrope(
                      color: cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Bar chart ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 196,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: onMute.withValues(alpha: isDark ? 0.07 : 0.06),
                      strokeWidth: 0.8,
                      dashArray: [4, 6],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => isDark
                          ? const Color(0xFF0D2030)
                          : const Color(0xFF0F1A1F),
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      getTooltipItem: (group, _, rod, __) {
                        final h = rod.toY;
                        if (h <= 0.03) return null;
                        return BarTooltipItem(
                          h < 1
                              ? '${(h * 60).round()}m'
                              : '${h.toStringAsFixed(1)}h',
                          GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: '\n${dayLabels[group.x]}',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= 7 || values[i] <= 0) {
                            return const SizedBox.shrink();
                          }
                          final h = values[i];
                          final isToday = i == todayIdx;
                          final isBest  = i == bestIdx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              h < 1 ? '${(h * 60).round()}m'
                                     : '${h.toStringAsFixed(1)}h',
                              style: GoogleFonts.manrope(
                                color: isToday
                                    ? cyan
                                    : isBest
                                        ? cyan.withValues(alpha: 0.75)
                                        : onMute.withValues(alpha: 0.55),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= 7) return const SizedBox.shrink();
                          final isToday = i == todayIdx;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayShort[i],
                                  style: GoogleFonts.inter(
                                    color: isToday ? cyan : onMute.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: isToday ? 5 : 3,
                                  height: isToday ? 5 : 3,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? cyan
                                        : onMute.withValues(alpha: 0.20),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final isToday = i == todayIdx;
                    final isBest  = i == bestIdx && hasData;
                    final v = values[i];
                    final isPast = i < todayIdx;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: v == 0 ? 0.03 : v,
                          width: isToday ? 22 : 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                            bottom: Radius.circular(3),
                          ),
                          gradient: v == 0
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isToday
                                      ? [
                                          cyan,
                                          cyan.withValues(alpha: 0.55),
                                        ]
                                      : isBest
                                          ? [
                                              cyan.withValues(alpha: 0.85),
                                              cyan.withValues(alpha: 0.35),
                                            ]
                                          : isPast
                                              ? [
                                                  cyan.withValues(alpha: 0.50),
                                                  cyan.withValues(alpha: 0.18),
                                                ]
                                              : [
                                                  onMute.withValues(alpha: 0.22),
                                                  onMute.withValues(alpha: 0.08),
                                                ],
                                ),
                          color: v == 0 ? Colors.transparent : null,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: trackCol,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          // ── Footer summary ───────────────────────────────────────────────
          if (hasData) ...[
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C1920).withValues(alpha: 0.8)
                    : cyan.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? cyan.withValues(alpha: 0.08)
                      : cyan.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  _FooterStat(
                    label: 'Active',
                    value: '$activeDays / 7 days',
                    color: cyan,
                    isDark: isDark,
                  ),
                  _FooterDivider(isDark: isDark),
                  _FooterStat(
                    label: 'Best day',
                    value: bestIdx >= 0 ? dayLabels[bestIdx].substring(0, 3) : '—',
                    color: cyan,
                    isDark: isDark,
                  ),
                  _FooterDivider(isDark: isDark),
                  _FooterStat(
                    label: 'Daily avg',
                    value: activeDays > 0
                        ? '${(totalHrs / activeDays).toStringAsFixed(1)}h'
                        : '—',
                    color: cyan,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _FooterStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onMute = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: onMute,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  final bool isDark;
  const _FooterDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.07),
    );
  }
}

class _FocusDonutChart extends StatelessWidget {
  final Map<String, int> subjectMap;
  final bool isDark;

  const _FocusDonutChart({required this.subjectMap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cyan      = isDark ? const Color(0xFF00C2D4) : const Color(0xFF007E90);
    final cardBg    = isDark ? const Color(0xFF080F14) : Colors.white;
    final border    = isDark ? const Color(0xFF162028) : const Color(0xFFDCEDF5);
    final onMute    = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);

    final entries = subjectMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top   = entries.take(4).toList();
    final total = top.fold(0, (acc, e) => acc + e.value);
    if (total == 0) return const SizedBox();
    final totalHours = total / 60.0;

    final values = top.map((e) => e.value.toDouble()).toList();
    final colors = [
      for (var i = 0; i < top.length; i++)
        AppTheme.subjectColors[i % AppTheme.subjectColors.length],
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: isDark ? 0.06 : 0.03),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Distribution',
                        style: GoogleFonts.manrope(
                          color: onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By subject · all time',
                        style: GoogleFonts.inter(
                          color: onMute,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cyan.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cyan.withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Text(
                    totalHours >= 1
                        ? '${totalHours.toStringAsFixed(1)}h total'
                        : '${total}m total',
                    style: GoogleFonts.manrope(
                      color: cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Chart + legend ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Donut
                SizedBox(
                  height: 122,
                  width: 122,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(122, 122),
                        painter: _DonutPainter(
                          values: values,
                          colors: colors,
                          isDark: isDark,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalHours >= 1
                                ? totalHours.toStringAsFixed(1)
                                : '$total',
                            style: GoogleFonts.manrope(
                              color: onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            totalHours >= 1 ? 'hrs' : 'min',
                            style: GoogleFonts.inter(
                              color: onMute,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'all time',
                            style: GoogleFonts.inter(
                              color: onMute.withValues(alpha: 0.55),
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: top.asMap().entries.map((entry) {
                      final i     = entry.key;
                      final e     = entry.value;
                      final color = AppTheme.subjectColors[i % AppTheme.subjectColors.length];
                      final hrs   = e.value / 60.0;
                      final pct   = e.value / total;
                      final pctInt = (pct * 100).round();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    boxShadow: isDark
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: GoogleFonts.inter(
                                      color: onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hrs >= 1
                                      ? '${hrs.toStringAsFixed(1)}h'
                                      : '${e.value}m',
                                  style: GoogleFonts.manrope(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                        alpha: isDark ? 0.14 : 0.10),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$pctInt%',
                                    style: GoogleFonts.manrope(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Mini progress bar with gradient fill
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    color: color.withValues(
                                        alpha: isDark ? 0.10 : 0.08),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: pct.clamp(0.0, 1.0),
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color,
                                            color.withValues(alpha: 0.50),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium donut: rounded, gapped gradient segments over a faint track, with a
/// soft glow behind the largest slice. Pure CustomPainter for full control.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final bool isDark;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint background track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: isDark ? 0.06 : 0.05),
    );

    // Soft glow behind the segments for a premium feel.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors.isNotEmpty
            ? colors.first.withValues(alpha: isDark ? 0.18 : 0.12)
            : Colors.transparent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final n = values.length;
    // Gap between segments (radians). Single segment = full ring, no gap.
    final gap = n > 1 ? 0.28 : 0.0;
    final available = (2 * math.pi) - (gap * n);
    var start = -math.pi / 2 + (n > 1 ? gap / 2 : 0);

    for (var i = 0; i < n; i++) {
      final sweep = (values[i] / total) * available;
      if (sweep <= 0) continue;
      final color = colors[i % colors.length];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [
            HSLColor.fromColor(color).withLightness(
              (HSLColor.fromColor(color).lightness + 0.12).clamp(0.0, 1.0),
            ).toColor(),
            color,
          ],
          transform: GradientRotation(start),
        ).createShader(rect);
      // Inset by half the cap so the rounded ends stay inside the segment.
      final capInset = (stroke / 2) / radius;
      final drawSweep = sweep - capInset;
      if (drawSweep > 0) {
        canvas.drawArc(rect, start + capInset / 2, drawSweep, false, paint);
      }
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors || old.isDark != isDark;
}

class _AiStatsRow extends StatelessWidget {
  final int summaries;
  final int flashcards;
  final int quizzes;
  final bool isDark;

  const _AiStatsRow({
    required this.summaries,
    required this.flashcards,
    required this.quizzes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, int count, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      color.withValues(alpha: 0.14),
                      color.withValues(alpha: 0.06),
                    ]
                  : [
                      color.withValues(alpha: 0.10),
                      Colors.white,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.10 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 9),
              Text(
                '$count',
                style: GoogleFonts.manrope(
                  color: isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDark
                      ? IslaColors.onSurfaceVariant
                      : const Color(0xFF5A6770),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Icons.notes_rounded, 'Summaries', summaries, const Color(0xFF10B981)),
        const SizedBox(width: 8),
        tile(Icons.style_rounded, 'Flashcards', flashcards, const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        tile(Icons.quiz_rounded, 'Quizzes', quizzes, const Color(0xFFF59E0B)),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String subject;
  final double progress;
  final String label;
  final Color color;

  const _SubjectRow({
    required this.subject,
    required this.progress,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final onMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final trackColor =
        isDark ? const Color(0xFF232628) : const Color(0xFFE5F0F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  subject,
                  style: GoogleFonts.inter(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              // Track
              Container(
                height: 9,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Filled portion with gradient
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progress * 100).round()}%',
            style: GoogleFonts.inter(
              color: onMute,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Marks Section ─────────────────────────────────────────────────────────

class _MarksSection extends StatelessWidget {
  const _MarksSection();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static FirebaseFirestore? get _db =>
      Firebase.apps.isEmpty ? null : FirebaseFirestore.instance;

  static Stream<List<Map<String, dynamic>>> _coursesStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value([]);
    return db
        .collection('courses')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Stream<List<Map<String, dynamic>>> _marksStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value([]);
    return db
        .collection('marks')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final marks = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      marks.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return (bTs as dynamic).compareTo(aTs as dynamic);
      });
      return marks;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final surfaceLow =
        isDark ? const Color(0xFF111415) : const Color(0xFFEAF2F6);
    final onMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _coursesStream(),
      builder: (context, coursesSnap) {
        final courses = coursesSnap.data ?? [];
        final courseNames = courses
            .map((c) => (c['name'] as String? ?? '').trim())
            .where((n) => n.isNotEmpty)
            .toList();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _marksStream(),
          builder: (context, snap) {
            final marks = snap.data ?? [];

            // Build subject set: all courses + any extra subjects already in marks
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            // Seed with all known courses (empty list)
            for (final name in courseNames) {
              grouped.putIfAbsent(name, () => []);
            }
            // Add actual marks
            for (final m in marks) {
              final sub = (m['subject'] as String? ?? 'Other').trim();
              grouped.putIfAbsent(sub, () => []).add(m);
            }
            final subjects = grouped.keys.toList()..sort();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Marks',
                      style: GoogleFonts.manrope(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _showAddMarkDialog(context, courseNames: courseNames, existingMarks: marks),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Mark'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (subjects.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No courses yet.\nAdd courses first, then track your marks here.',
                        style: GoogleFonts.inter(
                          color: onMute,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...subjects.map((sub) => _SubjectMarksCard(
                        subject: sub,
                        marks: grouped[sub]!,
                        onAddMark: () => _showAddMarkDialog(context,
                            subject: sub, courseNames: courseNames, existingMarks: marks),
                        onDeleteMark: (id) =>
                            _db?.collection('marks').doc(id).delete(),
                        onEditMark: (m) => _showEditMarkDialog(context, m),
                      )),
              ],
            );
          },
        );
      },
    );
  }

  /// Letter grade + colour for a 0–100 percentage.
  static ({String letter, Color color}) _gradeFor(double pct) {
    if (pct >= 80) return (letter: 'A', color: const Color(0xFF10B981));
    if (pct >= 70) return (letter: 'B', color: const Color(0xFF34D399));
    if (pct >= 60) return (letter: 'C', color: const Color(0xFFFFD166));
    if (pct >= 50) return (letter: 'D', color: const Color(0xFFFFA94D));
    if (pct >= 40) return (letter: 'E', color: const Color(0xFFFF8787));
    return (letter: 'F', color: const Color(0xFFFF4E4E));
  }

  static Future<void> _showAddMarkDialog(
    BuildContext context, {
    String? subject,
    List<String> courseNames = const [],
    List<Map<String, dynamic>> existingMarks = const [],
  }) async {
    String selectedSubject =
        subject ?? (courseNames.isNotEmpty ? courseNames.first : '');
    final customSubjectCtrl = TextEditingController(
        text: courseNames.contains(selectedSubject) ? '' : selectedSubject);
    final nameCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '100');
    String selectedType = 'Quiz';
    String? errorText;

    const types = [
      'Quiz', 'Assignment', 'Lab', 'Midterm', 'Final', 'Project', 'Other',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // All theme lookups use ctx (the dialog's own context) so Flutter
          // can track and clean up dependencies correctly on dialog dismiss.
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final surface = isDark ? const Color(0xFF0E1418) : Colors.white;
          final field = isDark ? const Color(0xFF161D22) : const Color(0xFFF1F5F8);
          final onSurface = isDark ? Colors.white : const Color(0xFF0F1A1F);
          final onMuted = isDark ? Colors.white60 : const Color(0xFF5A6770);
          final border = isDark ? const Color(0xFF24303A) : const Color(0xFFD4DEE4);

          InputDecoration deco(String label, {String? hint}) => InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: onMuted, fontSize: 13),
                hintStyle: TextStyle(color: onMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: field,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: IslaColors.primary, width: 1.6),
                ),
              );

          final score = double.tryParse(scoreCtrl.text.trim());
          final max = double.tryParse(maxCtrl.text.trim());
          final hasValidNums =
              score != null && max != null && max > 0 && score <= max;
          final pct = hasValidNums ? (score / max * 100) : null;
          final grade = pct != null ? _gradeFor(pct) : null;

          return Dialog(
            backgroundColor: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: IslaColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.grade_rounded,
                            color: IslaColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Add Mark',
                          style: TextStyle(
                              color: onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 20),

                    // ── Course ──────────────────────────────────────────────
                    if (courseNames.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: courseNames.contains(selectedSubject)
                            ? selectedSubject
                            : courseNames.first,
                        isExpanded: true,
                        dropdownColor: field,
                        style: TextStyle(color: onSurface, fontSize: 14),
                        decoration: deco('Course'),
                        items: courseNames
                            .map((n) =>
                                DropdownMenuItem(value: n, child: Text(n)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedSubject = v ?? ''),
                      )
                    else
                      TextField(
                        controller: customSubjectCtrl,
                        style: TextStyle(color: onSurface),
                        decoration: deco('Subject / Course',
                            hint: 'e.g. Web Engineering'),
                        onChanged: (v) => selectedSubject = v.trim(),
                      ),
                    const SizedBox(height: 12),

                    // ── Type (chips) ────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Type',
                          style: TextStyle(color: onMuted, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: types.map((t) {
                        final sel = t == selectedType;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: sel
                                  ? IslaColors.primary.withValues(alpha: 0.18)
                                  : field,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? IslaColors.primary
                                    : border,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    color: sel
                                        ? IslaColors.primary
                                        : onMuted,
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // ── Name ────────────────────────────────────────────────
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: onSurface),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: deco('Name', hint: '$selectedType 1'),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // ── Score / Out of ──────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: scoreCtrl,
                            style: TextStyle(color: onSurface),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: deco('Score'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('/',
                              style: TextStyle(
                                  fontSize: 22, color: onMuted)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            style: TextStyle(color: onSurface),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: deco('Out of'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),

                    // ── Live grade preview ──────────────────────────────────
                    if (grade != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: grade.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: grade.color.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: grade.color,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(grade.letter,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17)),
                          ),
                          const SizedBox(width: 12),
                          Text('${pct!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color: onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('Grade ${grade.letter}',
                              style: TextStyle(
                                  color: grade.color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],

                    // ── Inline error ────────────────────────────────────────
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFFF4E4E), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(errorText!,
                              style: const TextStyle(
                                  color: Color(0xFFFF4E4E), fontSize: 12.5)),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 18),

                    // ── Actions ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: TextStyle(color: onMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final sub = courseNames.isNotEmpty
                                ? selectedSubject
                                : customSubjectCtrl.text.trim();
                            final name = nameCtrl.text.trim();
                            final s = double.tryParse(scoreCtrl.text.trim());
                            final m = double.tryParse(maxCtrl.text.trim());

                            final effectiveName = name.isEmpty ? selectedType : name;
                            String? err;
                            if (sub.isEmpty) {
                              err = 'Choose or enter a course.';
                            } else if (s == null) {
                              err = 'Enter a valid score.';
                            } else if (m == null || m <= 0) {
                              err = 'Enter a valid "out of" total.';
                            } else if (s < 0) {
                              err = 'Score can\'t be negative.';
                            } else if (s > m) {
                              err = 'Score can\'t exceed the total ($m).';
                            }
                            if (err == null && m != null) {
                              final courseMarks = existingMarks
                                  .where((em) => (em['subject'] as String? ?? '') == sub);
                              final usedTotal = courseMarks.fold<double>(
                                  0, (acc, em) => acc + ((em['maxScore'] as num?) ?? 0));
                              if (usedTotal + m > 100) {
                                err = 'Total marks for this course would exceed 100 (${usedTotal.toInt()} already used).';
                              }
                            }
                            if (err != null) {
                              setDialogState(() => errorText = err);
                              return;
                            }

                            final db = _db;
                            final uid = _uid;
                            if (db == null || uid == null) return;
                            final ref = db.collection('marks').doc();
                            await ref.set({
                              'markId': ref.id,
                              'userId': uid,
                              'subject': sub,
                              'name': effectiveName,
                              'type': selectedType,
                              'score': s,
                              'maxScore': m,
                              'percentage': (s! / m! * 100).roundToDouble(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasValidNums
                                ? IslaColors.primary
                                : IslaColors.primary.withValues(alpha: 0.5),
                            foregroundColor: IslaColors.onPrimaryContainer,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    customSubjectCtrl.dispose();
    nameCtrl.dispose();
    scoreCtrl.dispose();
    maxCtrl.dispose();
  }

  static Future<void> _showEditMarkDialog(
    BuildContext context,
    Map<String, dynamic> mark,
  ) async {
    final nameCtrl = TextEditingController(text: mark['name'] as String? ?? '');
    final scoreCtrl = TextEditingController(
        text: ((mark['score'] as num?) ?? 0).toString());
    final maxCtrl = TextEditingController(
        text: ((mark['maxScore'] as num?) ?? 100).toString());
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final surface = isDark ? const Color(0xFF0E1418) : Colors.white;
          final field = isDark ? const Color(0xFF161D22) : const Color(0xFFF1F5F8);
          final onSurface = isDark ? Colors.white : const Color(0xFF0F1A1F);
          final onMuted = isDark ? Colors.white60 : const Color(0xFF5A6770);
          final border = isDark ? const Color(0xFF24303A) : const Color(0xFFD4DEE4);

          InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: onMuted, fontSize: 13),
                filled: true,
                fillColor: field,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: IslaColors.primary, width: 1.6)),
              );

          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: IslaColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_rounded, color: IslaColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Mark', style: TextStyle(color: onSurface, fontSize: 19, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: onSurface),
                    decoration: deco('Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: scoreCtrl,
                      style: TextStyle(color: onSurface),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: deco('Score'),
                      onChanged: (_) => setDialogState(() {}),
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('/', style: TextStyle(fontSize: 22, color: onMuted)),
                    ),
                    Expanded(child: TextField(
                      controller: maxCtrl,
                      style: TextStyle(color: onSurface),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: deco('Out of'),
                      onChanged: (_) => setDialogState(() {}),
                    )),
                  ]),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4E4E), size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(errorText!, style: const TextStyle(color: Color(0xFFFF4E4E), fontSize: 12.5))),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: TextStyle(color: onMuted)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final s = double.tryParse(scoreCtrl.text.trim());
                          final m = double.tryParse(maxCtrl.text.trim());
                          String? err;
                          if (s == null) {
                            err = 'Enter a valid score.';
                          } else if (m == null || m <= 0) {
                            err = 'Enter a valid total.';
                          } else if (s < 0) {
                            err = 'Score can\'t be negative.';
                          } else if (s > m) {
                            err = 'Score can\'t exceed the total.';
                          }
                          if (err != null) {
                            setDialogState(() => errorText = err);
                            return;
                          }
                          final db = _db;
                          if (db == null) return;
                          final id = mark['id'] as String?;
                          if (id == null) return;
                          await db.collection('marks').doc(id).update({
                            'name': name.isEmpty ? (mark['type'] ?? 'Mark') : name,
                            'score': s,
                            'maxScore': m,
                            'percentage': (s! / m! * 100).roundToDouble(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IslaColors.primary,
                          foregroundColor: IslaColors.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
    scoreCtrl.dispose();
    maxCtrl.dispose();
  }
}

// ─── Subject Marks Card ─────────────────────────────────────────────────────

class _SubjectMarksCard extends StatelessWidget {
  final String subject;
  final List<Map<String, dynamic>> marks;
  final VoidCallback onAddMark;
  final void Function(String id) onDeleteMark;
  final void Function(Map<String, dynamic> mark)? onEditMark;

  const _SubjectMarksCard({
    required this.subject,
    required this.marks,
    required this.onAddMark,
    required this.onDeleteMark,
    this.onEditMark,
  });

  double get _average {
    if (marks.isEmpty) return 0;
    final sum =
        marks.fold<double>(0, (a, m) => a + ((m['percentage'] as num?) ?? 0));
    return sum / marks.length;
  }

  Color get _gradeColor {
    final avg = _average;
    if (avg >= 80) return const Color(0xFF10B981);
    if (avg >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _grade {
    final avg = _average;
    if (avg >= 90) return 'A+';
    if (avg >= 85) return 'A';
    if (avg >= 80) return 'A-';
    if (avg >= 75) return 'B+';
    if (avg >= 70) return 'B';
    if (avg >= 65) return 'B-';
    if (avg >= 60) return 'C+';
    if (avg >= 55) return 'C';
    if (avg >= 50) return 'C-';
    if (avg >= 45) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceLow =
        isDark ? const Color(0xFF111415) : const Color(0xFFEAF2F6);
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final onMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gradeColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: GoogleFonts.manrope(
                          color: onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${marks.length} entr${marks.length == 1 ? 'y' : 'ies'}',
                        style: GoogleFonts.inter(
                          color: onMute,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (marks.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gradeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$_grade  ${_average.toStringAsFixed(1)}%',
                      style: GoogleFonts.manrope(
                        color: _gradeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded,
                      color: primary, size: 20),
                  tooltip: 'Add mark',
                  onPressed: onAddMark,
                ),
              ],
            ),
          ),
          // Marks list
          if (marks.isNotEmpty) ...[
            Divider(
              height: 1,
              color: _gradeColor.withValues(alpha: 0.15),
              indent: 14,
              endIndent: 14,
            ),
            ...marks.map((m) {
              final pct = (m['percentage'] as num? ?? 0).toDouble();
              final score = (m['score'] as num? ?? 0).toDouble();
              final maxScore = (m['maxScore'] as num? ?? 100).toDouble();
              final color = pct >= 80
                  ? const Color(0xFF10B981)
                  : pct >= 60
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);
              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                leading: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m['type'] as String? ?? '',
                    style: GoogleFonts.inter(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                title: Text(
                  m['name'] as String? ?? '',
                  style: GoogleFonts.inter(
                    color: onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score % 1 == 0 ? score.toInt() : score} / ${maxScore % 1 == 0 ? maxScore.toInt() : maxScore}',
                      style: GoogleFonts.manrope(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 14, color: onMute),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          onEditMark?.call(m);
                        } else if (v == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete mark?'),
                              content: Text(
                                  'Delete "${m['name'] ?? m['type'] ?? 'this mark'}"? This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            onDeleteMark(m['id'] as String);
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                size: 14, color: IslaColors.primary),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 14, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
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

/// Tappable CGPA card — shows current CGPA from gpa_records doc;
/// tapping opens the multi-semester GPA calculator.
class _CgpaCard extends StatelessWidget {
  final bool isDark;
  const _CgpaCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? const Color(0xFF111820)
        : Colors.white;
    final textPrimary =
        isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final textSecondary =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: GpaService.watchGpaRecord(),
      builder: (context, snap) {
        final record = snap.data;
        final cgpa = (record?['cgpa'] as num?)?.toDouble() ?? 0.0;
        final totalCredits = (record?['totalCredits'] as num?)?.toInt() ?? 0;
        final semesters =
            ((record?['semesters'] as List?) ?? []).length;
        final hasData = semesters > 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GPACalculatorScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AppTheme.primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CGPA',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData ? cgpa.toStringAsFixed(2) : '—',
                          style: GoogleFonts.manrope(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasData
                              ? '$semesters semester${semesters == 1 ? '' : 's'} · $totalCredits credits'
                              : 'Tap to set up your semesters',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_right_rounded,
                      color: textSecondary, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
