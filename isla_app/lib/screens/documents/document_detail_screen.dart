import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/document_service.dart';
import '../study_aids/summary_screen.dart';
import '../study_aids/flashcards_screen.dart';
import '../study_aids/quiz_screen.dart';
import 'pdf_annotation_screen.dart';

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

  /// Share the annotated PDF if one has been saved, otherwise share the
  /// original document URL so the recipient can open it directly.
  Future<void> _shareDocument(BuildContext context) async {
    final title = document['title'] as String? ?? 'Document';

    // 1. Try the saved annotated PDF first.
    final annotatedPath = document['annotatedFilePath'] as String?;
    if (annotatedPath != null && annotatedPath.isNotEmpty) {
      final f = File(annotatedPath);
      if (await f.exists()) {
        await Share.shareXFiles(
          [XFile(annotatedPath, mimeType: 'application/pdf', name: '$title (annotated).pdf')],
          subject: title,
          text: 'Annotated document from ISLA',
        );
        return;
      }
    }

    // 2. Fall back to the original download URL.
    final url = ((document['fileUrl'] ?? document['downloadUrl']) as String?) ?? '';
    if (url.isNotEmpty) {
      await Share.share(url, subject: title);
      return;
    }

    // 3. Nothing to share yet.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No annotated file yet. Open "Annotate / Draw", draw, then Save — then share.',
          ),
        ),
      );
    }
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
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 18),
            tooltip: 'Share annotated PDF',
            onPressed: () => _shareDocument(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (action) async {
              if (action == 'delete') {
                final docId = ((document['id'] ?? document['documentId']) as String?) ?? '';
                if (docId.isEmpty) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Document'),
                    content: Text('Delete "${document['title']}"? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await DocumentService.deleteDocument(docId);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: AppTheme.error)),
                ],
              )),
            ],
          ),
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
                        icon: Icons.folder_rounded,
                        label: 'Subject',
                        value: document['subject'] as String? ?? '—',
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Uploaded',
                        value: _formatDate(),
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.description_rounded,
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
                          builder: (_) => PdfAnnotationScreen(
                            documentTitle:
                                document['title'] as String? ?? 'Document',
                            documentId: (document['id'] ??
                                document['documentId']) as String?,
                            downloadUrl: (document['fileUrl'] ??
                                document['downloadUrl']) as String?,
                            storagePath: document['storagePath'] as String?,
                            fileName: document['fileName'] as String?,
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
                    icon: const Icon(Icons.edit_rounded, size: 18),
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
                      icon: Icons.description_rounded,
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
                      icon: Icons.layers_rounded,
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
                      icon: Icons.help_outline_rounded,
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
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Download Document',
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
        Icon(icon, color: AppTheme.textSecondary, size: 16),
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardColor = AppTheme.getCardColor(isDark);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Material(
      color: cardColor,
      borderRadius: AppTheme.borderRadiusMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.labelMedium.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_right_rounded, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
