import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/database_schema_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'home/home_screen.dart';
import 'planner/planner_screen.dart';
import 'timer/timer_screen.dart';
import 'documents/documents_screen.dart';
import 'study_aids/study_library_screen.dart';
import 'dashboard/dashboard_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isForwardNav = true;
  bool _schemaBootstrapStarted = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PlannerScreen(),
    const TimerScreen(),
    const DocumentsScreen(),
    const StudyLibraryScreen(),
    const DashboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapSchema();
  }

  Future<void> _bootstrapSchema() async {
    if (_schemaBootstrapStarted) return;
    _schemaBootstrapStarted = true;

    try {
      await DatabaseSchemaService.ensureEnhancedSchema();
    } catch (error, stackTrace) {
      // Keep navigation responsive even if migration fails.
      debugPrint('Schema bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isForwardNav = index > _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      body: Stack(
        children: List.generate(_screens.length, (index) {
          final isActive = _currentIndex == index;
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isActive: _currentIndex == 0,
                        onTap: () => _onTabSelected(0),
                        isDark: isDark,
                      ),
                      _NavBarItem(
                        icon: Icons.task_alt_outlined,
                        activeIcon: Icons.task_alt_rounded,
                        label: 'Tasks',
                        isActive: _currentIndex == 1,
                        onTap: () => _onTabSelected(1),
                        isDark: isDark,
                      ),
                      _NavBarItem(
                        icon: Icons.timelapse_outlined,
                        activeIcon: Icons.timelapse_rounded,
                        label: 'Session',
                        isActive: _currentIndex == 2,
                        onTap: () => _onTabSelected(2),
                        isDark: isDark,
                      ),
                      _NavBarItem(
                        icon: Icons.folder_open_outlined,
                        activeIcon: Icons.folder_rounded,
                        label: 'My Docs',
                        isActive: _currentIndex == 3,
                        onTap: () => _onTabSelected(3),
                        isDark: isDark,
                      ),
                      _NavBarItem(
                        icon: Icons.library_books_outlined,
                        activeIcon: Icons.library_books_rounded,
                        label: 'Library',
                        isActive: _currentIndex == 4,
                        onTap: () => _onTabSelected(4),
                        isDark: isDark,
                      ),
                      _NavBarItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        label: 'Analytics',
                        isActive: _currentIndex == 5,
                        onTap: () => _onTabSelected(5),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.getCardColor(isDark),
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
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 11,
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
