import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_schema_service.dart';
import '../services/nav_controller.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
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
    // Local alarms are cleared on reboot / reinstall — re-arm them from the
    // tasks in Firestore (the source of truth) every launch.
    TaskService.rescheduleAllReminders();
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
                  icon: Icons.timer_outlined,
                  activeIcon: Icons.timer_rounded,
                  label: 'Focus',
                  isActive: currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.checklist_outlined,
                  activeIcon: Icons.checklist_rounded,
                  label: 'Tasks',
                  isActive: currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.show_chart_rounded,
                  activeIcon: Icons.show_chart_rounded,
                  label: 'Analytics',
                  isActive: currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  label: 'Library',
                  isActive: currentIndex == 4,
                  onTap: () => _onTabSelected(4),
                  isDark: isDark,
                ),
                _NavBarItem(
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder_open_rounded,
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
    // Expanded → all 7 tabs share the row width equally and shrink to fit any
    // screen, instead of overflowing on narrower devices.
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Page ─────────────────────────────────────────────────────────────

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _uploadingPhoto = false;

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
                  const SizedBox(width: 48),
                ],
              ),

              const SizedBox(height: 20),

              // ── Hero card ─────────────────────────────────────────────────
              StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>?;
                  final studentId = data?['studentId'] as String? ?? '';
                  final faculty = data?['faculty'] as String? ?? '';
                  final semRaw = data?['semester'];
                  final semester = (semRaw != null &&
                          semRaw.toString().isNotEmpty &&
                          semRaw.toString() != '0')
                      ? semRaw.toString()
                      : '';
                  final hasAcademic =
                      studentId.isNotEmpty || faculty.isNotEmpty || semester.isNotEmpty;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: outlineSoft),
                    ),
                    child: Column(
                      children: [
                        // Avatar with camera badge
                        GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF00E3FD), Color(0xFF6BB9FF)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: _uploadingPhoto
                                    ? const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5, color: Colors.white),
                                        ),
                                      )
                                    : (data?['photoUrl'] as String?)?.isNotEmpty == true
                                        ? ClipOval(
                                            child: Image.network(
                                              data!['photoUrl'] as String,
                                              width: 92,
                                              height: 92,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(initials,
                                                    style: GoogleFonts.manrope(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 30)),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(initials,
                                                style: GoogleFonts.manrope(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 30)),
                                          ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: bg, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(displayName,
                            style: GoogleFonts.manrope(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 22)),
                        const SizedBox(height: 3),
                        Text(email,
                            style: GoogleFonts.inter(
                                color: textSecondary, fontSize: 13)),

                        // Academic chips
                        if (hasAcademic) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (studentId.isNotEmpty)
                                _AcademicChip(
                                    icon: Icons.badge_outlined,
                                    label: studentId,
                                    primary: primary,
                                    isDark: isDark),
                              if (faculty.isNotEmpty)
                                _AcademicChip(
                                    icon: Icons.school_outlined,
                                    label: faculty,
                                    primary: primary,
                                    isDark: isDark),
                              if (semester.isNotEmpty)
                                _AcademicChip(
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Sem $semester',
                                    primary: primary,
                                    isDark: isDark),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showEditProfileSheet(
                                context, displayName, '', '', ''),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline_rounded,
                                    color: primary.withValues(alpha: 0.65),
                                    size: 14),
                                const SizedBox(width: 4),
                                Text('Add academic info',
                                    style: GoogleFonts.inter(
                                        color: primary.withValues(alpha: 0.65),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditProfileSheet(
                                context, displayName, studentId, faculty, semester),
                            icon: const Icon(Icons.edit_rounded,
                                size: 14, color: AppTheme.primaryColor),
                            label: Text('Edit Profile',
                                style: GoogleFonts.inter(
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primary.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Appearance ────────────────────────────────────────────────
              _SectionLabel(label: 'Preferences', textColor: textSecondary),
              const SizedBox(height: 10),

              _SettingsCard(
                isDark: isDark,
                cardBg: cardBg,
                outlineSoft: outlineSoft,
                children: [
                  _SettingsTile(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
                    trailing: Icon(Icons.keyboard_arrow_right_rounded, color: textSecondary, size: 16),
                    onTap: () => _showNotificationsSheet(context),
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
                    trailing: Icon(Icons.keyboard_arrow_right_rounded, color: textSecondary, size: 16),
                    onTap: () => _showAboutIsla(context),
                  ),
                  _Divider(color: outlineSoft),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    primary: primary,
                    trailing: Icon(Icons.keyboard_arrow_right_rounded, color: textSecondary, size: 16),
                    onTap: () => _showHelpDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Log Out ───────────────────────────────────────────────────
              InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text(
                        'You will be signed out of ISLA. Your data is saved and '
                        'will be waiting when you log back in.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D4D),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
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

  // ── Pick & upload profile photo ──────────────────────────────────────────
  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() => _uploadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final ext = file.extension ?? 'jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('photo.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();

      await Future.wait([
        FirebaseAuth.instance.currentUser!.updatePhotoURL(url),
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'photoUrl': url}, SetOptions(merge: true)),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Edit Profile sheet ───────────────────────────────────────────────────
  void _showEditProfileSheet(BuildContext context, String name,
      String studentId, String faculty, String semester) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: name);
    final idCtrl = TextEditingController(text: studentId);
    final facCtrl = TextEditingController(text: faculty);
    final semCtrl = TextEditingController(text: semester);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111415) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Edit Profile',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: isDark
                          ? const Color(0xFFE8F4F7)
                          : const Color(0xFF0F1A1F))),
              const SizedBox(height: 20),
              _EditField(ctrl: nameCtrl, label: 'Display Name', icon: Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _EditField(ctrl: idCtrl, label: 'Student ID', icon: Icons.badge_outlined),
              const SizedBox(height: 12),
              _EditField(ctrl: facCtrl, label: 'Faculty', icon: Icons.school_outlined),
              const SizedBox(height: 12),
              _EditField(
                  ctrl: semCtrl,
                  label: 'Semester',
                  icon: Icons.calendar_today_rounded,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveProfile(
                      context,
                      nameCtrl.text.trim(),
                      idCtrl.text.trim(),
                      facCtrl.text.trim(),
                      semCtrl.text.trim(),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save Changes',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context, String name,
      String studentId, String faculty, String semester) async {
    try {
      if (name.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
          if (name.isNotEmpty) 'displayName': name,
          if (name.isNotEmpty) 'name': name,
          if (studentId.isNotEmpty) 'studentId': studentId,
          if (faculty.isNotEmpty) 'faculty': faculty,
          'semester': semester.isNotEmpty
              ? (int.tryParse(semester) ?? semester)
              : 0,
        }, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated'),
              backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
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

class _AcademicChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  final bool isDark;

  const _AcademicChip({
    required this.icon,
    required this.label,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          color: isDark ? const Color(0xFFE8F4F7) : const Color(0xFF0F1A1F),
          fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
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
      setState(() { _data = s; _loading = false; });
    });
  }

  Map<String, dynamic> get _n =>
      (_data?['notifications'] as Map?)?.cast<String, dynamic>() ?? {};

  Future<void> _update(Map<String, dynamic> patch) async {
    setState(() => patch.forEach((k, v) => _n[k] = v));
    await UserSettingsService.saveNotifications(
      taskReminders:     patch['taskReminders']     as bool?,
      pomodoroAlerts:    patch['pomodoroAlerts']    as bool?,
      streakReminder:    patch['streakReminder']    as bool?,
      streakHour:        patch['streakHour']        as int?,
      sessionStartAlert: patch['sessionStartAlert'] as bool?,
      sessionHalfAlert:  patch['sessionHalfAlert']  as bool?,
      morningReminder:   patch['morningReminder']   as bool?,
      morningHour:       patch['morningHour']       as int?,
      eveningReminder:   patch['eveningReminder']   as bool?,
      eveningHour:       patch['eveningHour']       as int?,
    );
    // Apply settings immediately — schedule or cancel as needed.
    _applySideEffects(patch);
  }

  void _applySideEffects(Map<String, dynamic> patch) {
    final svc = NotificationService.instance;

    // Morning reminder
    if (patch.containsKey('morningReminder') || patch.containsKey('morningHour')) {
      final on   = _bool('morningReminder', false);
      final hour = _int('morningHour', 8);
      if (on) {
        svc.scheduleMorningReminder(hour: hour);
      } else {
        svc.cancelMorningReminder();
      }
    }

    // Evening reminder
    if (patch.containsKey('eveningReminder') || patch.containsKey('eveningHour')) {
      final on   = _bool('eveningReminder', false);
      final hour = _int('eveningHour', 20);
      if (on) {
        svc.scheduleEveningReminder(hour: hour);
      } else {
        svc.cancelEveningReminder();
      }
    }

    // Streak reminder
    if (patch.containsKey('streakReminder') || patch.containsKey('streakHour')) {
      final on   = _bool('streakReminder', true);
      final hour = _int('streakHour', 20);
      if (on) {
        svc.scheduleDailyStreakReminder(hour: hour);
      } else {
        svc.cancelDailyStreakReminder();
      }
    }

    // Task reminders: when turned OFF cancel all scheduled advance reminders.
    if (patch.containsKey('taskReminders') && patch['taskReminders'] == false) {
      TaskService.cancelAllTaskReminders();
    }
  }

  bool _bool(String key, bool def) => (_n[key] as bool?) ?? def;
  int  _int(String key, int def)   => (_n[key] as num?)?.toInt() ?? def;

  String _fmtHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    final cardBg = AppTheme.getCardColor(isDark);

    if (_loading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }

    final taskOn       = _bool('taskReminders',    true);
    final pomoOn       = _bool('pomodoroAlerts',   true);
    final streakOn     = _bool('streakReminder',   true);
    final streakHour   = _int('streakHour',        20);
    final startAlert   = _bool('sessionStartAlert', true);
    final halfAlert    = _bool('sessionHalfAlert',  false);
    final morningOn    = _bool('morningReminder',   false);
    final morningHour  = _int('morningHour',         8);
    final eveningOn    = _bool('eveningReminder',   false);
    final eveningHour  = _int('eveningHour',        20);

    Widget sectionHeader(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppTheme.primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );

    Widget notifTile({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
      Widget? extra,
    }) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppTheme.primaryColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(title,
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 6), extra],
          ],
        );

    Widget hourSlider(int currentHour, ValueChanged<int> onHourChanged) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Slider(
              value: currentHour.toDouble(),
              min: 5,
              max: 23,
              divisions: 18,
              activeColor: AppTheme.primaryColor,
              label: _fmtHour(currentHour),
              onChanged: (v) => onHourChanged(v.round()),
            ),
          ),
          Text(
            _fmtHour(currentHour),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getBackgroundColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Notifications',
                style: GoogleFonts.manrope(
                  color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              'On web, alerts only fire while the tab is open. '
              'Install on Android/iOS for background reminders.',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12, height: 1.5),
            ),

            // ── Focus Sessions ─────────────────────────────────────────────
            sectionHeader('Focus Sessions'),
            notifTile(
              title: 'Session start alert',
              subtitle: 'Notify me when my focus timer begins.',
              value: startAlert,
              onChanged: (v) => _update({'sessionStartAlert': v}),
            ),
            const SizedBox(height: 8),
            notifTile(
              title: 'Halfway reminder',
              subtitle: 'Nudge me when I\'m halfway through a cycle.',
              value: halfAlert,
              onChanged: (v) => _update({'sessionHalfAlert': v}),
            ),
            const SizedBox(height: 8),
            notifTile(
              title: 'Cycle complete',
              subtitle: 'Notify me when a Pomodoro focus cycle ends.',
              value: pomoOn,
              onChanged: (v) => _update({'pomodoroAlerts': v}),
            ),

            // ── Tasks ──────────────────────────────────────────────────────
            sectionHeader('Tasks'),
            notifTile(
              title: 'Task reminders',
              subtitle: 'Notify me 12 hours before a task is due.',
              value: taskOn,
              onChanged: (v) => _update({'taskReminders': v}),
            ),

            // ── Daily Reminders ────────────────────────────────────────────
            sectionHeader('Daily Reminders'),
            notifTile(
              title: 'Morning study reminder',
              subtitle: 'A gentle nudge to start your study session.',
              value: morningOn,
              onChanged: (v) => _update({'morningReminder': v}),
              extra: morningOn
                  ? hourSlider(morningHour, (h) => _update({'morningHour': h}))
                  : null,
            ),
            const SizedBox(height: 8),
            notifTile(
              title: 'Evening study reminder',
              subtitle: 'Wind down your day with a quick study session.',
              value: eveningOn,
              onChanged: (v) => _update({'eveningReminder': v}),
              extra: eveningOn
                  ? hourSlider(eveningHour, (h) => _update({'eveningHour': h}))
                  : null,
            ),

            // ── Streaks ────────────────────────────────────────────────────
            sectionHeader('Streaks'),
            notifTile(
              title: 'Daily streak reminder',
              subtitle: 'Keep your streak alive with a daily nudge.',
              value: streakOn,
              onChanged: (v) => _update({'streakReminder': v}),
              extra: streakOn
                  ? hourSlider(streakHour, (h) => _update({'streakHour': h}))
                  : null,
            ),

            // ── Troubleshooting ────────────────────────────────────────────
            sectionHeader('Troubleshooting'),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final status =
                      await NotificationService.instance.sendTestNotification();
                  messenger.showSnackBar(SnackBar(content: Text(status)));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: const Text('Send test notification'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fires one now and one in 15 seconds. If the scheduled one is late, '
              'enable "Alarms & reminders" for ISLA in Android settings.',
              style: AppTheme.bodySmall.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}




// ─── Manage Subjects bottom sheet ────────────────────────────────────────────

