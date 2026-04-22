import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/document_service.dart';
import '../../widgets/isla_logo.dart';
import '../study_aids/summary_screen.dart';
import '../study_aids/flashcards_screen.dart';
import '../study_aids/quiz_screen.dart';
import 'document_detail_screen.dart';
import 'upload_document_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final Set<String> _collapsed = {};

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

  Color _courseColor(String courseName) {
    final idx =
        courseName.codeUnits.fold(0, (a, b) => a + b) % _courseColors.length;
    return _courseColors[idx];
  }

  void _openAI(BuildContext context, Map<String, dynamic> doc, String action) {
    late Widget screen;
    switch (action) {
      case 'summary':
        screen = SummaryScreen(document: doc);
        break;
      case 'flashcards':
        screen = FlashcardsScreen(document: doc);
        break;
      case 'quiz':
        screen = QuizScreen(document: doc);
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showCreateCourseDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Course'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Course name',
            hintText: 'e.g. BCS2033 or Data Structures',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await DocumentService.createCourse(controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course "${controller.text.trim()}" created'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _confirmDeleteCourse(String courseId, String courseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Course'),
        content: Text(
          'Delete "$courseName"? Documents in this course will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DocumentService.deleteCourse(courseId);
    }
  }

  void _uploadToCourse(String courseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadDocumentScreen(preselectedSubject: courseName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(isDark),
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
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: DocumentService.watchCourses(),
          builder: (context, courseSnap) {
            final courses = courseSnap.data ?? [];

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: DocumentService.watchDocuments(),
              builder: (context, docSnap) {
                final allDocs = docSnap.data ?? [];

                // Group docs by course name
                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (final course in courses) {
                  final name = (course['name'] as String? ?? '').trim();
                  if (name.isNotEmpty) grouped.putIfAbsent(name, () => []);
                }
                for (final doc in allDocs) {
                  final subject = (doc['subject'] as String? ?? '').trim();
                  if (subject.isNotEmpty && grouped.containsKey(subject)) {
                    grouped[subject]!.add(doc);
                  } else if (subject.isNotEmpty) {
                    // doc belongs to a course not yet created — show it anyway
                    grouped.putIfAbsent(subject, () => []).add(doc);
                  } else {
                    grouped.putIfAbsent('Uncategorized', () => []).add(doc);
                  }
                }

                final courseNames = grouped.keys.toList()..sort();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Documents',
                              style: AppTheme.headingLarge.copyWith(
                                color: AppTheme.getTextPrimary(isDark),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${allDocs.length} file${allDocs.length == 1 ? '' : 's'}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (courseNames.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open_rounded,
                                  size: 56, color: AppTheme.textLight),
                              const SizedBox(height: 12),
                              Text(
                                'No courses yet.\nTap + to create a course or upload a document.',
                                textAlign: TextAlign.center,
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final courseName = courseNames[index];
                            final docs = grouped[courseName] ?? [];
                            final isCollapsed = _collapsed.contains(courseName);
                            final color = _courseColor(courseName);
                            final courseObj = courses.firstWhere(
                              (c) => (c['name'] as String?) == courseName,
                              orElse: () => {},
                            );
                            final courseId = courseObj['id'] as String?;

                            return _CourseSectionCard(
                              courseName: courseName,
                              color: color,
                              docs: docs,
                              isDark: isDark,
                              isCollapsed: isCollapsed,
                              courseId: courseId,
                              onToggleCollapse: () => setState(() {
                                isCollapsed
                                    ? _collapsed.remove(courseName)
                                    : _collapsed.add(courseName);
                              }),
                              onAddDoc: () => _uploadToCourse(courseName),
                              onDeleteCourse: courseId != null
                                  ? () =>
                                      _confirmDeleteCourse(courseId, courseName)
                                  : null,
                              onDocTap: (doc) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentDetailScreen(document: doc),
                                ),
                              ),
                              onDocAction: (doc, action) {
                                if (action == 'delete') {
                                  DocumentService.deleteDocument(
                                      doc['id'] as String);
                                } else {
                                  _openAI(context, doc, action);
                                }
                              },
                            );
                          },
                          childCount: courseNames.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'newCourseFab',
            onPressed: _showCreateCourseDialog,
            backgroundColor: AppTheme.getCardColor(isDark),
            foregroundColor: AppTheme.primaryColor,
            elevation: 2,
            icon: const Icon(Icons.create_new_folder_rounded),
            label: const Text('New Course'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'uploadDocFab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
            ),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
            label:
                const Text('Upload Doc', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Course Section Card ───────────────────────────────────────────────────

class _CourseSectionCard extends StatelessWidget {
  final String courseName;
  final Color color;
  final List<Map<String, dynamic>> docs;
  final bool isDark;
  final bool isCollapsed;
  final String? courseId;
  final VoidCallback onToggleCollapse;
  final VoidCallback onAddDoc;
  final VoidCallback? onDeleteCourse;
  final void Function(Map<String, dynamic>) onDocTap;
  final void Function(Map<String, dynamic>, String) onDocAction;

  const _CourseSectionCard({
    required this.courseName,
    required this.color,
    required this.docs,
    required this.isDark,
    required this.isCollapsed,
    required this.courseId,
    required this.onToggleCollapse,
    required this.onAddDoc,
    required this.onDeleteCourse,
    required this.onDocTap,
    required this.onDocAction,
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
                )
              ],
      ),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            onTap: onToggleCollapse,
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
                          courseName,
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.getTextPrimary(isDark),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${docs.length} document${docs.length == 1 ? '' : 's'}',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.getTextSecondary(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: color, size: 22),
                    tooltip: 'Upload document to this course',
                    onPressed: onAddDoc,
                  ),
                  if (onDeleteCourse != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: AppTheme.getTextSecondary(isDark), size: 20),
                      onSelected: (v) {
                        if (v == 'delete') onDeleteCourse!();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded,
                                size: 18, color: AppTheme.error),
                            SizedBox(width: 8),
                            Text('Delete Course',
                                style: TextStyle(color: AppTheme.error)),
                          ]),
                        ),
                      ],
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
          // ── Document list ──
          if (!isCollapsed) ...[
            Divider(
              height: 1,
              color: color.withOpacity(0.15),
              indent: 14,
              endIndent: 14,
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.upload_file_rounded,
                        color: AppTheme.getTextSecondary(isDark), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'No documents yet — tap + to add one',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: color.withOpacity(0.1),
                  indent: 64,
                  endIndent: 14,
                ),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  return _DocumentListTile(
                    doc: doc,
                    color: color,
                    isDark: isDark,
                    onTap: () => onDocTap(doc),
                    onAction: (action) => onDocAction(doc, action),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Document List Tile ─────────────────────────────────────────────────────

class _DocumentListTile extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final void Function(String) onAction;

  const _DocumentListTile({
    required this.doc,
    required this.color,
    required this.isDark,
    required this.onTap,
    required this.onAction,
  });

  IconData get _typeIcon {
    switch (doc['type'] ?? '') {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'PPTX':
        return Icons.slideshow_rounded;
      case 'DOCX':
        return Icons.article_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['title'] ?? '',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        doc['type'] ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextSecondary(isDark),
                          fontSize: 11,
                        ),
                      ),
                      if (doc['size'] != null) ...[
                        Text(' • ',
                            style: TextStyle(
                                color: AppTheme.getTextLight(isDark),
                                fontSize: 11)),
                        Text(
                          doc['size'],
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.getTextSecondary(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: AppTheme.getTextSecondary(isDark), size: 20),
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'summary',
                  child: Row(children: [
                    Icon(Icons.summarize_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Summarize'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'flashcards',
                  child: Row(children: [
                    Icon(Icons.style_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Flashcards'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'quiz',
                  child: Row(children: [
                    Icon(Icons.quiz_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Quiz'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 18, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppTheme.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
