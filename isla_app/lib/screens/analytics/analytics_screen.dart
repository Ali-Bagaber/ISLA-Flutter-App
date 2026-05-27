import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/gpa_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';
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

  static Stream<Map<String, dynamic>> _analyticsStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value({});
    return db
        .collection('analytics')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? s.data()! : <String, dynamic>{});
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

  static Stream<Map<String, int>> _subjectMinutesStream() {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return Stream.value({});
    return db
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final map = <String, int>{};
      for (final doc in snap.docs) {
        final subject = (doc.data()['subject'] ?? 'Other').toString();
        final mins = (doc.data()['focusMinutes'] as num? ?? 0).toInt();
        map[subject] = (map[subject] ?? 0) + mins;
      }
      return map;
    });
  }

  String _formatMinutes(int mins) {
    if (mins >= 60) return '${(mins / 60).toStringAsFixed(1)}h';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? IslaColors.background : const Color(0xFFF4FBFE);
    final appBarBg = isDark ? IslaColors.background.withValues(alpha: 0.95) : const Color(0xF8FFFFFF);
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final onSurfaceMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final outlineSoft = isDark
        ? IslaColors.outlineVariant.withValues(alpha: 0.4)
        : const Color(0xFFD4DEE4);
    final surfaceHigh =
        isDark ? const Color(0xFF232628) : const Color(0xFFE5F0F5);

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
              decoration: BoxDecoration(
                color: appBarBg,
                border: Border(bottom: BorderSide(color: outlineSoft)),
              ),
              child: Row(
                children: [
                  const IslaLogo(markSize: 28, textSize: 17),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            context.read<ThemeProvider>().setDarkMode(!isDark),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: onSurfaceMute,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'logout') {
                            await AuthService.signOut();
                            if (context.mounted) context.goNamed('splash');
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(children: [
                              Icon(Icons.logout_rounded,
                                  color: onSurfaceMute, size: 18),
                              const SizedBox(width: 8),
                              const Text('Sign Out'),
                            ]),
                          ),
                        ],
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: surfaceHigh,
                          child: Icon(Icons.person, color: primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: _analyticsStream(),
                builder: (context, analyticsSnap) {
                  final analytics = analyticsSnap.data ?? {};
                  final totalMins =
                      (analytics['totalStudyTime'] as num? ?? 0).toInt();
                  final sessionCount =
                      (analytics['sessionCount'] as num? ?? 0).toInt();
                  final streak =
                      (analytics['streak'] as num? ?? 0).toInt();

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

                              return StreamBuilder<Map<String, int>>(
                                stream: _subjectMinutesStream(),
                                builder: (context, subjectSnap) {
                                  final subjectMap = subjectSnap.data ?? {};
                                  final topSubjects = subjectMap.entries
                                      .toList()
                                    ..sort(
                                        (a, b) => b.value.compareTo(a.value));
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
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient:
                                                      IslaColors.cyanToBlue,
                                                ),
                                                child: const Icon(Icons.person,
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
                                              label: 'Longest Streak',
                                              value: streak > 0 ? '$streak days' : '\u2014',
                                              change: streak > 0 ? 'New record \ud83d\udd25' : 'Start your streak',
                                              positive: streak > 0,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _CgpaCard(isDark: isDark),
                                        const SizedBox(height: 18),
                                        _SectionLabel(label: 'Weekly Focus', isDark: isDark),
                                        const SizedBox(height: 10),
                                        _WeeklyBarChart(totalMins: totalMins, isDark: isDark),
                                        const SizedBox(height: 18),
                                        if (subjectMap.isNotEmpty) ...[
                                          _SectionLabel(label: 'Focus Distribution', isDark: isDark),
                                          const SizedBox(height: 10),
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
                                            child: Column(
                                              children: topSubjects
                                                  .take(5)
                                                  .map(
                                                    (e) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 10),
                                                      child: _SubjectRow(
                                                        subject: e.key,
                                                        progress:
                                                            e.value / maxMins,
                                                        label: _formatMinutes(
                                                            e.value),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
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
                  );
                },
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
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F),
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final int totalMins;
  final bool isDark;

  const _WeeklyBarChart({required this.totalMins, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final cardBg = isDark ? const Color(0xFF111415) : const Color(0xFFFFFFFF);
    final onMute = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);

    // Distribute totalMins across weekdays with a realistic pattern.
    // When no data, show flat zero bars rather than fake fractional-hour blobs.
    const weights = [0.19, 0.22, 0.18, 0.16, 0.13, 0.07, 0.05];
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final hasData = totalMins > 0;
    final base = hasData ? totalMins.toDouble() : 0.0;
    final values = weights.map((w) => (base * w / 60).clamp(0.0, 24.0)).toList();
    final maxY = hasData
        ? (values.reduce((a, b) => a > b ? a : b) * 1.25).clamp(0.5, 24.0)
        : 4.0;

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: onMute.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox();
                  return Text(
                    days[i],
                    style: GoogleFonts.inter(
                      color: onMute,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [primary, primary.withValues(alpha: 0.5)],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _FocusDonutChart extends StatelessWidget {
  final Map<String, int> subjectMap;
  final bool isDark;

  const _FocusDonutChart({required this.subjectMap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111415) : const Color(0xFFFFFFFF);
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final onMute = isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);

    final entries = subjectMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final total = top.fold(0, (acc, e) => acc + e.value);
    if (total == 0) return const SizedBox();

    final sections = top.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final pct = (e.value / total * 100).round();
      final color = AppTheme.subjectColors[i % AppTheme.subjectColors.length];
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        radius: 44,
        title: '$pct%',
        titleStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: top.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final color = AppTheme.subjectColors[i % AppTheme.subjectColors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
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
                      Expanded(
                        child: Text(
                          e.key,
                          style: GoogleFonts.inter(
                            color: onMute,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String subject;
  final double progress;
  final String label;

  const _SubjectRow(
      {required this.subject, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? IslaColors.onSurface : const Color(0xFF0F1A1F);
    final onMute =
        isDark ? IslaColors.onSurfaceVariant : const Color(0xFF5A6770);
    final primary = isDark ? IslaColors.primary : const Color(0xFF007E90);
    final surfaceHigh =
        isDark ? const Color(0xFF232628) : const Color(0xFFE5F0F5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: GoogleFonts.inter(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: surfaceHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: onMute,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: surfaceHigh,
            valueColor: AlwaysStoppedAnimation(primary),
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
                          _showAddMarkDialog(context, courseNames: courseNames),
                      icon: const Icon(Icons.add_rounded, size: 18),
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
                            subject: sub, courseNames: courseNames),
                        onDeleteMark: (id) =>
                            _db?.collection('marks').doc(id).delete(),
                      )),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _showAddMarkDialog(
    BuildContext context, {
    String? subject,
    List<String> courseNames = const [],
  }) async {
    String selectedSubject =
        subject ?? (courseNames.isNotEmpty ? courseNames.first : '');
    final customSubjectCtrl = TextEditingController(
        text: courseNames.contains(selectedSubject) ? '' : selectedSubject);
    bool useCustomSubject =
        !courseNames.contains(selectedSubject) && courseNames.isNotEmpty
            ? false
            : courseNames.isEmpty;
    final nameCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '100');
    String selectedType = 'Quiz';

    const types = [
      'Quiz',
      'Assignment',
      'Lab',
      'Midterm',
      'Final',
      'Project',
      'Other',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Mark'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subject — dropdown if courses exist, else text field
                if (courseNames.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: courseNames.contains(selectedSubject)
                        ? selectedSubject
                        : courseNames.first,
                    decoration: const InputDecoration(labelText: 'Course'),
                    items: courseNames
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedSubject = v ?? ''),
                  )
                else
                  TextField(
                    controller: customSubjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject / Course',
                      hintText: 'e.g. Web Engineering',
                    ),
                    onChanged: (v) => selectedSubject = v.trim(),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedType = v ?? 'Quiz'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: '$selectedType 1',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: scoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Score'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('/', style: TextStyle(fontSize: 20)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Out of'),
                      ),
                    ),
                  ],
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
                final sub = courseNames.isNotEmpty
                    ? selectedSubject
                    : customSubjectCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final score = double.tryParse(scoreCtrl.text.trim());
                final max = double.tryParse(maxCtrl.text.trim());
                if (sub.isEmpty ||
                    name.isEmpty ||
                    score == null ||
                    max == null ||
                    max <= 0) {
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
                  'name': name,
                  'type': selectedType,
                  'score': score,
                  'maxScore': max,
                  'percentage': (score / max * 100).roundToDouble(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IslaColors.primary,
                foregroundColor: IslaColors.onPrimaryContainer,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    customSubjectCtrl.dispose();
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

  const _SubjectMarksCard({
    required this.subject,
    required this.marks,
    required this.onAddMark,
    required this.onDeleteMark,
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
          color: _gradeColor.withOpacity(0.2),
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
                      color: _gradeColor.withOpacity(0.12),
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
                      color: primary, size: 22),
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
              color: _gradeColor.withOpacity(0.15),
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
                    color: color.withOpacity(0.12),
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
                      icon: Icon(Icons.more_vert, size: 16, color: onMute),
                      onSelected: (v) {
                        if (v == 'delete') {
                          onDeleteMark(m['id'] as String);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded,
                                size: 16, color: Colors.red),
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
                        color: AppTheme.primaryColor, size: 28),
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
                  Icon(Icons.chevron_right_rounded,
                      color: textSecondary, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
