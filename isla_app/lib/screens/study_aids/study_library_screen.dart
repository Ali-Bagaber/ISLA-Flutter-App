import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/gemini_study_service.dart';
import '../../widgets/isla_logo.dart';
import 'quiz_screen.dart';

class StudyLibraryScreen extends StatefulWidget {
  const StudyLibraryScreen({super.key});

  @override
  State<StudyLibraryScreen> createState() => _StudyLibraryScreenState();
}

class _StudyLibraryScreenState extends State<StudyLibraryScreen> {
  String _selectedTab = 'All';
  final Set<String> _collapsed = {};

  final List<String> _tabs = ['All', 'Summary', 'Flashcards', 'Quiz'];

  static const List<Color> _courseColors = [
    Color(0xFF6366F1),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  Color _colorForSubject(String subject) {
    if (subject.isEmpty) return AppTheme.primaryColor;
    final idx =
        subject.codeUnits.fold(0, (a, b) => a + b) % _courseColors.length;
    return _courseColors[idx];
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Summary':
        return Icons.summarize_rounded;
      case 'Flashcards':
        return Icons.style_rounded;
      case 'Quiz':
        return Icons.quiz_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final backgroundColor = AppTheme.getBackgroundColor(isDark);
    final appBarColor =
        isDark ? AppTheme.libraryBackgroundBase : AppTheme.getCardColor(isDark);
    final titleColor = AppTheme.getTextPrimary(isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const IslaLogo(),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: IslaProfileAvatar()),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: GeminiStudyService.watchStudyMaterials(),
        builder: (context, snapshot) {
          final allMaterials = snapshot.data ?? [];
          final filtered = _selectedTab == 'All'
              ? allMaterials
              : allMaterials.where((m) => m['type'] == _selectedTab).toList();

          // Group by subject/course
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final m in filtered) {
            final sub = (m['subject'] as String? ?? '').trim();
            final key = sub.isEmpty ? 'Other' : sub;
            grouped.putIfAbsent(key, () => []).add(m);
          }
          final subjects = grouped.keys.toList()..sort();

          return Container(
            decoration: AppTheme.getBackgroundDecoration(isDark),
            child: Column(
              children: [
                _buildTabsBar(isDark),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 64,
                                  color: AppTheme.getTextSecondary(isDark)
                                      .withValues(alpha: 0.45),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Loading...'
                                      : 'No saved materials yet.\n\nGenerate summaries, flashcards or\nquizzes from My Documents!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondary(isDark),
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                                  style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.getTextSecondary(isDark)),
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final subject = subjects[i];
                                  final items = grouped[subject]!;
                                  final color = _colorForSubject(subject);
                                  final isCollapsed =
                                      _collapsed.contains(subject);
                                  return _CourseGroupCard(
                                    subject: subject,
                                    color: color,
                                    items: items,
                                    isDark: isDark,
                                    isCollapsed: isCollapsed,
                                    iconForType: _iconForType,
                                    onToggle: () => setState(() {
                                      isCollapsed
                                          ? _collapsed.remove(subject)
                                          : _collapsed.add(subject);
                                    }),
                                    onTap: _openMaterial,
                                  );
                                },
                                childCount: subjects.length,
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 24)),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabsBar(bool isDark) {
    final inactiveText = AppTheme.getTextSecondary(isDark);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.getSurfaceColor(isDark),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            final isSelected = _selectedTab == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: InkWell(
                onTap: () => setState(() => _selectedTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : inactiveText,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openMaterial(Map<String, dynamic> material) {
    final type = material['type'] as String? ?? '';
    final content = material['content'] as String? ?? '';

    if (type == 'Summary') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SavedSummaryView(material: material),
        ),
      );
    } else if (type == 'Flashcards') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SavedFlashcardsView(material: material),
        ),
      );
    } else if (type == 'Quiz') {
      // Re-open quiz with saved questions
      List<Map<String, dynamic>> questions = [];
      try {
        final decoded = jsonDecode(content) as List;
        questions = decoded
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            document: {
              'title': material['title'] ?? '',
              'subject': material['subject'] ?? '',
            },
            savedQuestions: questions,
          ),
        ),
      );
    }
  }
}

// ── Course Group Card ─────────────────────────────────────────────────────────
class _CourseGroupCard extends StatelessWidget {
  final String subject;
  final Color color;
  final List<Map<String, dynamic>> items;
  final bool isDark;
  final bool isCollapsed;
  final IconData Function(String) iconForType;
  final VoidCallback onToggle;
  final void Function(Map<String, dynamic>) onTap;

  const _CourseGroupCard({
    required this.subject,
    required this.color,
    required this.items,
    required this.isDark,
    required this.isCollapsed,
    required this.iconForType,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: AppTheme.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          '${items.length} item${items.length == 1 ? '' : 's'}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.getTextSecondary(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppTheme.getTextSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),
          // Items
          if (!isCollapsed) ...[
            Divider(
                height: 1,
                color: color.withOpacity(0.15),
                indent: 14,
                endIndent: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: color.withOpacity(0.1),
                indent: 64,
                endIndent: 14,
              ),
              itemBuilder: (ctx, i) {
                final m = items[i];
                final type = m['type'] as String? ?? 'Summary';
                return InkWell(
                  onTap: () => onTap(m),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(iconForType(type), color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['title'] as String? ?? '',
                                style: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.getTextPrimary(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                type,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.getTextSecondary(isDark),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppTheme.getTextLight(isDark), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Saved Summary Viewer ──────────────────────────────────────────────────────
class _SavedSummaryView extends StatelessWidget {
  final Map<String, dynamic> material;
  const _SavedSummaryView({required this.material});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final content = material['content'] as String? ?? '';
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Summary'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: const Text('Saved',
                  style: TextStyle(fontSize: 12, color: AppTheme.success)),
              avatar: const Icon(Icons.check_circle_rounded,
                  size: 14, color: AppTheme.success),
              backgroundColor: AppTheme.success.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.summarize_rounded,
                        color: AppTheme.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(material['title'] ?? '',
                              style: AppTheme.labelMedium),
                          Text(material['subject'] ?? '',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(content, style: AppTheme.bodyMedium.copyWith(height: 1.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Saved Flashcards Viewer ───────────────────────────────────────────────────
class _SavedFlashcardsView extends StatefulWidget {
  final Map<String, dynamic> material;
  const _SavedFlashcardsView({required this.material});

  @override
  State<_SavedFlashcardsView> createState() => _SavedFlashcardsViewState();
}

class _SavedFlashcardsViewState extends State<_SavedFlashcardsView> {
  int _index = 0;
  bool _showAnswer = false;
  late List<Map<String, String>> _cards;

  @override
  void initState() {
    super.initState();
    try {
      final decoded = jsonDecode(widget.material['content'] as String) as List;
      _cards = decoded
          .map<Map<String, String>>((e) => {
                'question': e['question'].toString(),
                'answer': e['answer'].toString()
              })
          .toList();
    } catch (_) {
      _cards = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Flashcards')),
        body: const Center(child: Text('No flashcard data found.')),
      );
    }
    final card = _cards[_index];
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Flashcards'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: const Text('Saved',
                  style: TextStyle(fontSize: 11, color: AppTheme.success)),
              avatar: const Icon(Icons.check_circle_rounded,
                  size: 13, color: AppTheme.success),
              backgroundColor: AppTheme.success.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
          ),
          TextButton(
            onPressed: null,
            child: Text('${_index + 1}/${_cards.length}',
                style: AppTheme.labelMedium
                    .copyWith(color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: LinearProgressIndicator(
                value: (_index + 1) / _cards.length,
                backgroundColor: AppTheme.surfaceColor,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => setState(() => _showAnswer = !_showAnswer),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey<bool>(_showAnswer),
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: _showAnswer
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : const LinearGradient(
                                colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryLight
                                  ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                        borderRadius: AppTheme.borderRadiusLarge,
                        boxShadow: [
                          BoxShadow(
                              color: (_showAnswer
                                      ? const Color(0xFF8B5CF6)
                                      : AppTheme.primaryColor)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10))
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(_showAnswer ? 'Answer' : 'Question',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _showAnswer ? card['answer']! : card['question']!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text('Tap to flip',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index > 0
                          ? () => setState(() {
                                _index--;
                                _showAnswer = false;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _index < _cards.length - 1
                          ? () => setState(() {
                                _index++;
                                _showAnswer = false;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
