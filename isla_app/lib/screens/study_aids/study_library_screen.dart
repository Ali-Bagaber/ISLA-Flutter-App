import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'summary_screen.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';

class StudyLibraryScreen extends StatefulWidget {
  const StudyLibraryScreen({super.key});

  @override
  State<StudyLibraryScreen> createState() => _StudyLibraryScreenState();
}

class _StudyLibraryScreenState extends State<StudyLibraryScreen> {
  String _selectedTab = 'All Materials';
  String? _selectedTopic;
  
  final List<String> _tabs = ['All Materials', 'Summaries', 'Flashcards', 'Quizzes', 'Notes'];
  
  final List<Map<String, dynamic>> _topics = [
    {
      'name': 'Data Structures',
      'subject': 'BCS2033',
      'color': AppTheme.subjectColors[0],
      'materials': 15,
    },
    {
      'name': 'Software Engineering',
      'subject': 'BCS3012',
      'color': AppTheme.subjectColors[1],
      'materials': 12,
    },
    {
      'name': 'Database Design',
      'subject': 'BCS2042',
      'color': AppTheme.subjectColors[2],
      'materials': 8,
    },
    {
      'name': 'Web Development',
      'subject': 'BCS4051',
      'color': AppTheme.subjectColors[3],
      'materials': 10,
    },
  ];
  
  final List<Map<String, dynamic>> _allMaterials = [
    {
      'title': 'Introduction to Data Structures',
      'type': 'Summary',
      'topic': 'Data Structures',
      'subject': 'BCS2033',
      'date': 'Today',
      'items': '5 key points',
      'color': AppTheme.subjectColors[0],
      'icon': Icons.summarize_rounded,
    },
    {
      'title': 'Stacks and Queues',
      'type': 'Flashcards',
      'topic': 'Data Structures',
      'subject': 'BCS2033',
      'date': 'Yesterday',
      'items': '12 cards',
      'color': AppTheme.subjectColors[0],
      'icon': Icons.style_rounded,
    },
    {
      'title': 'Arrays & Linked Lists Quiz',
      'type': 'Quiz',
      'topic': 'Data Structures',
      'subject': 'BCS2033',
      'date': '2 days ago',
      'items': '10 questions',
      'color': AppTheme.subjectColors[0],
      'icon': Icons.quiz_rounded,
    },
    {
      'title': 'SDLC Models Summary',
      'type': 'Summary',
      'topic': 'Software Engineering',
      'subject': 'BCS3012',
      'date': '3 days ago',
      'items': '6 key points',
      'color': AppTheme.subjectColors[1],
      'icon': Icons.summarize_rounded,
    },
    {
      'title': 'Software Testing Types',
      'type': 'Flashcards',
      'topic': 'Software Engineering',
      'subject': 'BCS3012',
      'date': '4 days ago',
      'items': '8 cards',
      'color': AppTheme.subjectColors[1],
      'icon': Icons.style_rounded,
    },
    {
      'title': 'Requirements Analysis',
      'type': 'Quiz',
      'topic': 'Software Engineering',
      'subject': 'BCS3012',
      'date': '5 days ago',
      'items': '15 questions',
      'color': AppTheme.subjectColors[1],
      'icon': Icons.quiz_rounded,
    },
    {
      'title': 'Normalization Summary',
      'type': 'Summary',
      'topic': 'Database Design',
      'subject': 'BCS2042',
      'date': '1 week ago',
      'items': '4 key points',
      'color': AppTheme.subjectColors[2],
      'icon': Icons.summarize_rounded,
    },
    {
      'title': 'SQL Queries Practice',
      'type': 'Flashcards',
      'topic': 'Database Design',
      'subject': 'BCS2042',
      'date': '1 week ago',
      'items': '20 cards',
      'color': AppTheme.subjectColors[2],
      'icon': Icons.style_rounded,
    },
  ];
  
  List<Map<String, dynamic>> get _filteredMaterials {
    var materials = _allMaterials;
    
    // Filter by topic
    if (_selectedTopic != null) {
      materials = materials.where((m) => m['topic'] == _selectedTopic).toList();
    }
    
    // Filter by tab
    if (_selectedTab != 'All Materials') {
      if (_selectedTab == 'Summaries') {
        materials = materials.where((m) => m['type'] == 'Summary').toList();
      } else if (_selectedTab == 'Flashcards') {
        materials = materials.where((m) => m['type'] == 'Flashcards').toList();
      } else if (_selectedTab == 'Quizzes') {
        materials = materials.where((m) => m['type'] == 'Quiz').toList();
      }
    }
    
    return materials;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        title: const Text(
          'Study Library',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - Topics
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Color(0xFF0F111D),
              border: Border(
                right: BorderSide(color: Color(0xFF2A2D3E), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topics Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Topics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_topics.length}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Topics List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      final isSelected = _selectedTopic == topic['name'];
                      return _TopicItem(
                        name: topic['name'],
                        subject: topic['subject'],
                        color: topic['color'],
                        materials: topic['materials'],
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedTopic = isSelected ? null : topic['name'];
                          });
                        },
                      );
                    },
                  ),
                ),
                
                // Add Topic Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2A2D3E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Topic'),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Tabs
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1D2E),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2D3E), width: 1),
                    ),
                  ),
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
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Materials Grid
                Expanded(
                  child: _filteredMaterials.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 64,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No materials yet',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: _filteredMaterials.length,
                          itemBuilder: (context, index) {
                            final material = _filteredMaterials[index];
                            return _MaterialCard(
                              material: material,
                              onTap: () => _openMaterial(material),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _openMaterial(Map<String, dynamic> material) {
    final mockDocument = {
      'title': material['title'],
      'subject': material['subject'],
      'type': 'PDF',
      'size': '2.5 MB',
      'date': material['date'],
      'color': material['color'],
    };
    
    Widget screen;
    if (material['type'] == 'Summary') {
      screen = SummaryScreen(document: mockDocument);
    } else if (material['type'] == 'Flashcards') {
      screen = FlashcardsScreen(document: mockDocument);
    } else {
      screen = QuizScreen(document: mockDocument);
    }
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _TopicItem extends StatelessWidget {
  final String name;
  final String subject;
  final Color color;
  final int materials;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicItem({
    required this.name,
    required this.subject,
    required this.color,
    required this.materials,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2A2D3E) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.topic_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$materials materials',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF6366F1),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final VoidCallback onTap;

  const _MaterialCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2A2D3E),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (material['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      material['icon'],
                      color: material['color'],
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (material['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      material['type'],
                      style: TextStyle(
                        color: material['color'],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                material['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    material['date'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    material['items'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
