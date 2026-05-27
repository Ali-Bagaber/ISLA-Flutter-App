// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../study_aids/summary_screen.dart';
import '../study_aids/flashcards_screen.dart';
import '../study_aids/quiz_screen.dart';
import 'document_annotate_screen.dart';

class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> document;

  const DocumentDetailScreen({super.key, required this.document});

  Color _docColor() {
    final subject = document['subject'] as String? ?? '';
    const subjects = ['BCS2033', 'BCS3012', 'BCS2042', 'BCS4051'];
    final idx = subjects.indexOf(subject);
    if (idx == -1) return AppTheme.primaryColor;
    return AppTheme.subjectColors[idx % AppTheme.subjectColors.length];
  }

  String _formatDate() {
    final raw = document['createdAt'];
    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is DateTime) {
      dt = raw;
    }
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _docIcon() {
    final type = (document['type'] as String? ?? '').toUpperCase();
    if (type == 'PDF') return Icons.picture_as_pdf_rounded;
    if (type == 'PPTX') return Icons.slideshow_rounded;
    if (type == 'DOCX') return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final color = _docColor();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Preview
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(isDark),
                  borderRadius: AppTheme.borderRadiusLarge,
                  boxShadow: isDark ? [] : AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_docIcon(), size: 64, color: color),
                    const SizedBox(height: 16),
                    Text(
                      document['title'] as String? ?? 'Untitled',
                      style: AppTheme.headingSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${document['type'] ?? ''} • ${document['size'] ?? ''}',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Document Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(isDark),
                    borderRadius: AppTheme.borderRadiusMedium,
                    boxShadow: isDark ? [] : AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.folder_outlined,
                        label: 'Subject',
                        value: document['subject'] as String? ?? '—',
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Uploaded',
                        value: _formatDate(),
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.insert_drive_file_outlined,
                        label: 'File Type',
                        value: document['type'] as String? ?? '—',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Annotate Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentAnnotateScreen(
                            documentTitle:
                                document['title'] as String? ?? 'Document',
                            documentId: (document['id'] ??
                                document['documentId']) as String?,
                            downloadUrl: (document['fileUrl'] ??
                                document['downloadUrl']) as String?,
                            fileType: document['type'] as String? ?? 'PDF',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.draw_rounded),
                    label: const Text(
                      'Annotate / Draw',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // AI Study Aids Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('AI Study Aids', style: AppTheme.headingSmall),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Generate study materials from this document using AI',
                  style: AppTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 16),

              // Study Aid Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _StudyAidCard(
                      icon: Icons.summarize_rounded,
                      title: 'Generate Summary',
                      description: 'Create an extractive summary of key points',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SummaryScreen(document: document),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _StudyAidCard(
                      icon: Icons.style_rounded,
                      title: 'Generate Flashcards',
                      description: 'Create Q&A flashcards for revision',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FlashcardsScreen(document: document),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _StudyAidCard(
                      icon: Icons.quiz_rounded,
                      title: 'Generate Quiz',
                      description: 'Test your knowledge with MCQ questions',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(document: document),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Open Document Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final url = ((document['fileUrl'] ??
                              document['downloadUrl']) as String?) ??
                          '';
                      if (url.isNotEmpty) {
                        html.window.open(url, '_blank');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text(
                      'Open Document',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(value, style: AppTheme.labelMedium),
      ],
    );
  }
}

class _StudyAidCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _StudyAidCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppTheme.borderRadiusMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(color: color.withOpacity(0.2)),
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
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(description, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
