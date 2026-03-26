import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../study_aids/summary_screen.dart';
import '../study_aids/flashcards_screen.dart';
import '../study_aids/quiz_screen.dart';

class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Preview
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 64,
                    color: document['color'],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    document['title'],
                    style: AppTheme.headingSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${document['type']} • ${document['size']}',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Document Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.folder_outlined,
                      label: 'Subject',
                      value: document['subject'],
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Uploaded',
                      value: document['date'],
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'File Type',
                      value: document['type'],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // AI Study Aids Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('AI Study Aids', style: AppTheme.headingSmall),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Generate study materials from this document using AI',
                style: AppTheme.bodySmall,
              ),
            ),

            const SizedBox(height: 16),

            // Study Aid Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          builder: (_) => FlashcardsScreen(document: document),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'Open Document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
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
