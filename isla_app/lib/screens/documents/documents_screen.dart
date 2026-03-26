import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import 'document_detail_screen.dart';
import 'upload_document_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedSubject = 'All';
  final List<String> _subjects = ['All', 'BCS2033', 'BCS3012', 'BCS2042', 'BCS4051'];
  
  final List<Map<String, dynamic>> _documents = [
    {
      'title': 'Data Structures - Chapter 1',
      'subject': 'BCS2033',
      'type': 'PDF',
      'size': '2.5 MB',
      'date': 'Jan 1, 2026',
      'color': AppTheme.subjectColors[0],
    },
    {
      'title': 'Software Engineering Notes',
      'subject': 'BCS3012',
      'type': 'PDF',
      'size': '1.8 MB',
      'date': 'Dec 28, 2025',
      'color': AppTheme.subjectColors[1],
    },
    {
      'title': 'Database Design Slides',
      'subject': 'BCS2042',
      'type': 'PPTX',
      'size': '5.2 MB',
      'date': 'Dec 25, 2025',
      'color': AppTheme.subjectColors[2],
    },
    {
      'title': 'OOP Concepts Summary',
      'subject': 'BCS2033',
      'type': 'PDF',
      'size': '890 KB',
      'date': 'Dec 20, 2025',
      'color': AppTheme.subjectColors[0],
    },
    {
      'title': 'Web Development Tutorial',
      'subject': 'BCS4051',
      'type': 'PDF',
      'size': '3.1 MB',
      'date': 'Dec 18, 2025',
      'color': AppTheme.subjectColors[3],
    },
  ];

  List<Map<String, dynamic>> get _filteredDocuments {
    if (_selectedSubject == 'All') return _documents;
    return _documents.where((doc) => doc['subject'] == _selectedSubject).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('My Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Subject Filter
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                final isSelected = subject == _selectedSubject;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(subject),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedSubject = subject);
                    },
                    backgroundColor: AppTheme.getCardColor(isDark),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.1),
                    checkmarkColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.getTextSecondary(isDark),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Document Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredDocuments.length} documents',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.getTextSecondary(isDark),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
                    const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                    const PopupMenuItem(value: 'size', child: Text('Sort by Size')),
                  ],
                ),
              ],
            ),
          ),
          
          // Document List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredDocuments.length,
              itemBuilder: (context, index) {
                final doc = _filteredDocuments[index];
                return _DocumentListItem(
                  title: doc['title'],
                  subject: doc['subject'],
                  type: doc['type'],
                  size: doc['size'],
                  date: doc['date'],
                  color: doc['color'],
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentDetailScreen(document: doc),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _DocumentListItem extends StatelessWidget {
  final String title;
  final String subject;
  final String type;
  final String size;
  final String date;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _DocumentListItem({
    required this.title,
    required this.subject,
    required this.type,
    required this.size,
    required this.date,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  IconData get _typeIcon {
    switch (type) {
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTheme.borderRadiusMedium,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(type, style: AppTheme.bodySmall.copyWith(color: AppTheme.getTextSecondary(isDark))),
                          Text(' • ', style: TextStyle(color: AppTheme.getTextLight(isDark))),
                          Text(size, style: AppTheme.bodySmall.copyWith(color: AppTheme.getTextSecondary(isDark))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextLight(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppTheme.getTextLight(isDark)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'summary',
                      child: Row(
                        children: [
                          Icon(Icons.summarize_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Generate Summary'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'flashcards',
                      child: Row(
                        children: [
                          Icon(Icons.style_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Generate Flashcards'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'quiz',
                      child: Row(
                        children: [
                          Icon(Icons.quiz_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Generate Quiz'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 20, color: AppTheme.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
