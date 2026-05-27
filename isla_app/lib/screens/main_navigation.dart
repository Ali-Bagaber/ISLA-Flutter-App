import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_schema_service.dart';
import '../services/nav_controller.dart';
import '../services/notification_service.dart';
import '../services/user_settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/isla_logo.dart';
import 'home/home_screen.dart';
import 'tasks/tasks_screen.dart';
import 'timer/timer_screen.dart';
import 'study_aids/study_library_screen.dart';
import 'analytics/analytics_screen.dart';
import 'documents/documents_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  /// Tracks last-seen tab index so we can drive the slide animation direction.
  int _lastIndex = 0;
  bool _isForwardNav = true;
  bool _schemaBootstrapStarted = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TimerScreen(),
    const TasksScreen(),
    const AnalyticsScreen(),
    const StudyLibraryScreen(),
    const DocumentsScreen(),
    const _ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapSchema();
    _runMissedStudyCheck();
  }

  /// Once-per-launch: if yesterday was one of the user's planned study days
  /// and they didn't log a focus session, surface a gentle reminder.
  Future<void> _runMissedStudyCheck() async {
    try {
      final settings = await UserSettingsService.loadSettings();
      final plan = (settings['studyPlan'] as Map?)?.cast<String, dynamic>() ??
          const {};
      final days = (plan['studyDays'] as List?)?.cast<num>().map((n) => n.toInt()).toList() ??
          const <int>[];
      if (days.isEmpty) return;

      // Did the user have a session yesterday?
      final yesterdayHad = await _yesterdayHadSession();
      await NotificationService.instance.checkMissedStudyDay(
        studyDays: days,
        yesterdayHadSession: yesterdayHad,
      );
    } catch (_) {
      // Best-effort. Never block app launch.
    }
  }

  Future<bool> _yesterdayHadSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || Firebase.apps.isEmpty) return true; // assume ok
    final now = DateTime.now();
    final yStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final yEnd = yStart.add(const Duration(days: 1));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('userId', isEqualTo: uid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(yStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(yEnd))
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return true; // failsafe — don't spam the user if the query fails
    }
  }

  Future<void> _bootstrapSchema() async {
    if (_schemaBootstrapStarted) return;
    _schemaBootstrapStarted = true;

    try {
      await DatabaseSchemaService.ensureEnhancedSchema();
    } catch (error, stackTrace) {
      debugPrint('Schema bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onTabSelected(int index) {
    final nav = context.read<NavController>();
    if (index == nav.index) return;
    HapticFeedback.selectionClick();
    nav.goTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final currentIndex = context.watch<NavController>().index;
    // Compute slide direction (forward vs back) using the last seen index.
    if (currentIndex != _lastIndex) {
      _isForwardNav = currentIndex > _lastIndex;
      _lastIndex = currentIndex;
    }

    return Scaffold(
      body: Stack(
        children: List.generate(_screens.length, (index) {
          final isActive = currentIndex == index;
          final inactiveOffset =
              _isForwardNav ? const Offset(-0.02, 0) : const Offset(0.02, 0);

          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !isActive,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : inactiveOffset,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: isActive ? 1 : 0,
                  child: TickerMode(
                    enabled: isActive,
                    child: _screens[index],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.getSurfaceColor(isDark),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavBarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.radio_button_unchecked_outlined,
                  activeIcon: Icons.radio_button_checked_rounded,
                  label: 'Focus',
                  isActive: currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.task_alt_outlined,
                  activeIcon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  isActive: currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Analytics',
                  isActive: currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.library_books_outlined,
                  activeIcon: Icons.library_books_rounded,
                  label: 'Library',
                  isActive: currentIndex == 4,
                  onTap: () => _onTabSelected(4),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder_rounded,
                  label: 'Docs',
                  isActive: currentIndex == 5,
                  onTap: () => _onTabSelected(5),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: currentIndex == 6,
                  onTap: () => _onTabSelected(6),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.getTextSecondary(isDark),
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.getTextSecondary(isDark),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Page ─────────────────────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  static Stream<int> _streakStream() {
    if (Firebase.apps.isEmpty) return Stream.value(0);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('analytics')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['streak'] as num? ?? 0).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Student';
    final email = user?.email ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : 'S';

    final bg = AppTheme.getBackgroundColor(isDark);
    final cardBg = AppTheme.getCardColor(isDark);
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    const primary = AppTheme.primaryColor;
    final surface = AppTheme.getSurfaceColor(isDark);
    final outlineSoft = isDark
        ? const Color(0xFF2A2E32)
        : const Color(0xFFD4DEE4);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AppBar Row ────────────────────────────────────────────────
              Row(
                children: [
                  const IslaLogo(),
                  const Spacer(),
                  Text(
                    'Profile',
                    style: GoogleFonts.manrope(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: textSecondary, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Avatar + Name ─────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00E3FD), Color(0xFF6BB9FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: user?.photoURL != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photoURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: GoogleFonts.manrope(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context, displayName),
                      icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryColor),
                      label: Text(
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Appearance ────────────────────────────────────────────────
              _SectionLabel(label: 'Preferences', textColor: textSecondary),
              const SizedBox(height: 10),

              _SettingsCard(
                isDark: isDark,
                cardBg: cardBg,
                outlineSoft: outlineSoft,
                children: [
                  _SettingsTile(
                    icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    label: isDark ? 'Dark Mode' : 'Light Mode',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Switch.adaptive(
                      value: isDark,
                      onChanged: (v) => themeProvider.setDarkMode(v),
                      activeThumbColor: primary,
                      activeTrackColor: primary.withValues(alpha: 0.35),
                    ),
                  ),
                  _Divider(color: outlineSoft),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => _showNotificationsSheet(context),
                  ),
                  _Divider(color: outlineSoft),
                  _SettingsTile(
                    icon: Icons.timer_outlined,
                    label: 'Focus Preferences',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => _showFocusPrefsSheet(context),
                  ),
                  _Divider(color: outlineSoft),
                  _SettingsTile(
                    icon: Icons.event_available_rounded,
                    label: 'Study Plan',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => _showStudyPlanSheet(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Study Streak ──────────────────────────────────────────────
              StreamBuilder<int>(
                stream: _streakStream(),
                builder: (context, streakSnap) {
                  final streak = streakSnap.data ?? 0;
                  final dotsActive = streak.clamp(0, 7);
                  final streakLabel = streak == 0
                      ? 'Start your streak!'
                      : streak == 1
                          ? '1 day streak'
                          : '$streak day streak';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary.withValues(alpha: 0.12),
                          const Color(0xFF6BB9FF).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B2B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_fire_department_rounded,
                              color: Color(0xFFFF6B2B), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Study Streak',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              streakLabel,
                              style: GoogleFonts.manrope(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(7, (i) {
                            final active = i < dotsActive;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? const Color(0xFFFF6B2B)
                                    : surface.withValues(alpha: 0.6),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── About / Support ───────────────────────────────────────────
              _SectionLabel(label: 'About', textColor: textSecondary),
              const SizedBox(height: 10),

              _SettingsCard(
                isDark: isDark,
                cardBg: cardBg,
                outlineSoft: outlineSoft,
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About ISLA',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => _showAboutIsla(context),
                  ),
                  _Divider(color: outlineSoft),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => _showHelpDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Log Out ───────────────────────────────────────────────────
              InkWell(
                onTap: () async {
                  await AuthService.signOut();
                  if (context.mounted) context.goNamed('splash');
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF4D4D).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Color(0xFFFF4D4D), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF4D4D),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Profile ──────────────────────────────────────────────────────────
  Future<void> _showEditProfileDialog(
      BuildContext context, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'displayName': newName}, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationsSheet(),
    );
  }

  void _showFocusPrefsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FocusPrefsSheet(),
    );
  }

  void _showStudyPlanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _StudyPlanSheet(),
    );
  }

  void _showAboutIsla(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ISLA',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset(
        'assets/images/isla_logo_512.png',
        width: 48,
        height: 48,
      ),
      applicationLegalese:
          '© 2026 ISLA — Intelligent Study & Learning Assistant',
      children: const [
        SizedBox(height: 14),
        Text(
          'ISLA is an AI-powered study assistant that helps you focus, '
          'organise your tasks, and verify what you have learned. '
          'Built with Flutter, Firebase, and Google Gemini.',
          style: TextStyle(height: 1.5),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Help & Support'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpTip(
                title: 'Focus sessions',
                body:
                    'Plan a study block in the Focus tab. Add a goal, link a document, then start the timer. After cycles end you get a Quick Check with AI questions.',
              ),
              SizedBox(height: 12),
              _HelpTip(
                title: 'AI study aids',
                body:
                    'Upload a document in Docs. Open it to generate a Summary, Flashcards or a Quiz from its actual content.',
              ),
              SizedBox(height: 12),
              _HelpTip(
                title: 'GPA / CGPA',
                body:
                    'In Analytics, tap the CGPA card to add semesters and courses. The CGPA updates live as you edit grades.',
              ),
              SizedBox(height: 12),
              _HelpTip(
                title: 'Notifications',
                body:
                    'On mobile, ISLA sends reminders 12h before a task is due and when a focus block ends. On web, notifications only fire while the tab is open.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HelpTip extends StatelessWidget {
  final String title;
  final String body;
  const _HelpTip({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 12, height: 1.45)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textColor;

  const _SectionLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color outlineSoft;
  final List<Widget> children;

  const _SettingsCard({
    required this.isDark,
    required this.cardBg,
    required this.outlineSoft,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineSoft),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color, indent: 50, endIndent: 16);
  }
}

// ─── Notifications settings bottom sheet ─────────────────────────────────────

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UserSettingsService.loadSettings().then((s) {
      if (!mounted) return;
      setState(() {
        _data = s;
        _loading = false;
      });
    });
  }

  Map<String, dynamic> get _n =>
      (_data?['notifications'] as Map?)?.cast<String, dynamic>() ?? {};

  Future<void> _update({
    bool? taskReminders,
    bool? pomodoroAlerts,
    bool? streakReminder,
    int? streakHour,
  }) async {
    setState(() {
      _n['taskReminders'] = taskReminders ?? _n['taskReminders'];
      _n['pomodoroAlerts'] = pomodoroAlerts ?? _n['pomodoroAlerts'];
      _n['streakReminder'] = streakReminder ?? _n['streakReminder'];
      _n['streakHour'] = streakHour ?? _n['streakHour'];
    });
    await UserSettingsService.saveNotifications(
      taskReminders: taskReminders,
      pomodoroAlerts: pomodoroAlerts,
      streakReminder: streakReminder,
      streakHour: streakHour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);

    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final taskOn = _n['taskReminders'] == true;
    final pomoOn = _n['pomodoroAlerts'] == true;
    final streakOn = _n['streakReminder'] == true;
    final hour = (_n['streakHour'] as num?)?.toInt() ?? 20;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Notifications',
                style: GoogleFonts.manrope(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                )),
            const SizedBox(height: 4),
            Text(
              'On the web, alerts only fire while the tab is open. '
              'For background reminders, install the app on Android/iOS.',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: taskOn,
              onChanged: (v) => _update(taskReminders: v),
              activeThumbColor: AppTheme.primaryColor,
              title: const Text('Task reminders'),
              subtitle:
                  const Text('Notify me 12 hours before a task is due.'),
            ),
            SwitchListTile(
              value: pomoOn,
              onChanged: (v) => _update(pomodoroAlerts: v),
              activeThumbColor: AppTheme.primaryColor,
              title: const Text('Pomodoro alerts'),
              subtitle: const Text('Notify me when a focus cycle ends.'),
            ),
            SwitchListTile(
              value: streakOn,
              onChanged: (v) => _update(streakReminder: v),
              activeThumbColor: AppTheme.primaryColor,
              title: const Text('Daily streak reminder'),
              subtitle: Text(
                  'Nudge me to study at ${hour.toString().padLeft(2, '0')}:00.'),
            ),
            if (streakOn) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Hour:', style: TextStyle(color: textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: hour.toDouble(),
                        min: 6,
                        max: 23,
                        divisions: 17,
                        label: '${hour.toString().padLeft(2, '0')}:00',
                        onChanged: (v) => _update(streakHour: v.round()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Focus preferences bottom sheet ──────────────────────────────────────────

class _FocusPrefsSheet extends StatefulWidget {
  const _FocusPrefsSheet();

  @override
  State<_FocusPrefsSheet> createState() => _FocusPrefsSheetState();
}

class _FocusPrefsSheetState extends State<_FocusPrefsSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UserSettingsService.loadSettings().then((s) {
      if (!mounted) return;
      setState(() {
        _data = s;
        _loading = false;
      });
    });
  }

  Map<String, dynamic> get _f =>
      (_data?['focus'] as Map?)?.cast<String, dynamic>() ?? {};

  Future<void> _update({int? work, int? brk, int? cycles}) async {
    setState(() {
      _f['workMinutes'] = work ?? _f['workMinutes'];
      _f['breakMinutes'] = brk ?? _f['breakMinutes'];
      _f['cycles'] = cycles ?? _f['cycles'];
    });
    await UserSettingsService.saveFocus(
      workMinutes: work,
      breakMinutes: brk,
      cycles: cycles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);

    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final work = (_f['workMinutes'] as num?)?.toInt() ?? 25;
    final brk = (_f['breakMinutes'] as num?)?.toInt() ?? 5;
    final cycles = (_f['cycles'] as num?)?.toInt() ?? 4;

    Widget chips({
      required String label,
      required List<int> options,
      required int selected,
      required void Function(int) onSelect,
      required String suffix,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
            child: Text(label,
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final sel = opt == selected;
              return InkWell(
                onTap: () => onSelect(opt),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppTheme.primaryColor.withValues(alpha: 0.18)
                        : AppTheme.getSurfaceColor(isDark),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: sel
                          ? AppTheme.primaryColor
                          : AppTheme.getSurfaceColor(isDark),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '$opt $suffix',
                    style: TextStyle(
                      color: sel ? AppTheme.primaryColor : textSecondary,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Focus Preferences',
                style: GoogleFonts.manrope(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                )),
            const SizedBox(height: 4),
            Text(
              'These become the defaults the next time you start a focus session.',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            chips(
              label: 'Focus duration',
              options: const [15, 20, 25, 30, 45, 60],
              selected: work,
              onSelect: (v) => _update(work: v),
              suffix: 'min',
            ),
            const SizedBox(height: 12),
            chips(
              label: 'Break duration',
              options: const [3, 5, 10, 15],
              selected: brk,
              onSelect: (v) => _update(brk: v),
              suffix: 'min',
            ),
            const SizedBox(height: 12),
            chips(
              label: 'Cycles per session',
              options: const [2, 3, 4, 5, 6],
              selected: cycles,
              onSelect: (v) => _update(cycles: v),
              suffix: 'cycles',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Study plan bottom sheet ─────────────────────────────────────────────────

/// Lets the user edit the onboarding answers any time after onboarding:
/// focus subject, deadline, session minutes and which weekdays they study.
class _StudyPlanSheet extends StatefulWidget {
  const _StudyPlanSheet();

  @override
  State<_StudyPlanSheet> createState() => _StudyPlanSheetState();
}

class _StudyPlanSheetState extends State<_StudyPlanSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _subjects = [
    'Operating Systems',
    'Data Structures',
    'Mathematics',
    'Database Systems',
    'Software Engineering',
    'Computer Networks',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    UserSettingsService.loadSettings().then((s) {
      if (!mounted) return;
      setState(() {
        _data = s;
        _loading = false;
      });
    });
  }

  Map<String, dynamic> get _p =>
      (_data?['studyPlan'] as Map?)?.cast<String, dynamic>() ?? {};

  Future<void> _update({
    String? focusSubject,
    DateTime? deadline,
    int? sessionMinutes,
    List<int>? studyDays,
  }) async {
    setState(() {
      if (focusSubject != null) _p['focusSubject'] = focusSubject;
      if (deadline != null) {
        _p['deadlineMillis'] = deadline.millisecondsSinceEpoch;
      }
      if (sessionMinutes != null) _p['sessionMinutes'] = sessionMinutes;
      if (studyDays != null) _p['studyDays'] = studyDays;
    });
    await UserSettingsService.saveStudyPlan(
      focusSubject: focusSubject,
      deadline: deadline,
      sessionMinutes: sessionMinutes,
      studyDays: studyDays,
    );
    // Mirror sessionMinutes to focus prefs so the timer reads the latest.
    if (sessionMinutes != null) {
      await UserSettingsService.saveFocus(workMinutes: sessionMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    final surface = AppTheme.getSurfaceColor(isDark);

    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final subject = (_p['focusSubject'] as String?) ?? 'Operating Systems';
    final sessionMins = (_p['sessionMinutes'] as num?)?.toInt() ?? 25;
    final daysList = (_p['studyDays'] as List?)?.cast<num>()
            .map((n) => n.toInt())
            .toSet() ??
        {1, 2, 3, 4, 5, 6, 7};
    final deadlineMillis = (_p['deadlineMillis'] as num?)?.toInt();
    final deadline = deadlineMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(deadlineMillis)
        : DateTime.now().add(const Duration(days: 14));

    String formatDate(DateTime d) {
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
        'Dec'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Study Plan',
              style: GoogleFonts.manrope(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Update the answers you gave during onboarding.',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Subject
            Text('Focus Subject',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue:
                  _subjects.contains(subject) ? subject : _subjects.first,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => _update(focusSubject: v ?? subject),
            ),
            const SizedBox(height: 14),

            // Deadline
            Text('Deadline',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: deadline,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) _update(deadline: picked);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Text(formatDate(deadline),
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: textSecondary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Session minutes
            Text('Session Goal Time',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [15, 25, 50].map((m) {
                final selected = sessionMins == m;
                return InkWell(
                  onTap: () => _update(sessionMinutes: m),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryColor.withValues(alpha: 0.18)
                          : surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text('$m min',
                        style: TextStyle(
                          color: selected
                              ? AppTheme.primaryColor
                              : textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Study days
            Text('Study Days',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = daysList.contains(day);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () {
                        final next = Set<int>.from(daysList);
                        if (selected) {
                          if (next.length > 1) next.remove(day);
                        } else {
                          next.add(day);
                        }
                        _update(studyDays: next.toList()..sort());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor.withValues(alpha: 0.16)
                              : surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _dayLabels[i],
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : textSecondary,
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
          ],
        ),
      ),
    );
  }
}
