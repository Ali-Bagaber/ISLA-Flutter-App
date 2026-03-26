import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class FlashcardsScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const FlashcardsScreen({super.key, required this.document});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool _isGenerating = true;
  int _currentIndex = 0;
  bool _showAnswer = false;

  final List<Map<String, String>> _flashcards = [
    {
      'question': 'What is a Data Structure?',
      'answer': 'A data structure is a specialized format for organizing, processing, retrieving and storing data. It enables efficient access and modification of data based on specific requirements.',
    },
    {
      'question': 'What is the difference between an Array and a Linked List?',
      'answer': 'Arrays store elements in contiguous memory locations with O(1) access time. Linked Lists store elements with pointers to next elements, allowing O(1) insertion/deletion but O(n) access time.',
    },
    {
      'question': 'What is Big O Notation?',
      'answer': 'Big O notation describes the upper bound of algorithm complexity, representing the worst-case scenario for time or space requirements as input size grows.',
    },
    {
      'question': 'What is a Stack?',
      'answer': 'A Stack is a LIFO (Last In First Out) data structure where elements are added and removed from the same end. Common operations: push, pop, peek.',
    },
    {
      'question': 'What is a Queue?',
      'answer': 'A Queue is a FIFO (First In First Out) data structure where elements are added at rear and removed from front. Common operations: enqueue, dequeue.',
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    });
  }

  void _nextCard() {
    setState(() {
      if (_currentIndex < _flashcards.length - 1) {
        _currentIndex++;
        _showAnswer = false;
      }
    });
  }

  void _previousCard() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
        _showAnswer = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          if (!_isGenerating)
            TextButton(
              onPressed: () {},
              child: Text(
                '${_currentIndex + 1}/${_flashcards.length}',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Generating Flashcards...',
                    style: AppTheme.headingSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Creating Q&A cards from your document',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.document['title'],
                            style: AppTheme.bodySmall,
                          ),
                          Text(
                            '${((_currentIndex + 1) / _flashcards.length * 100).toInt()}%',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentIndex + 1) / _flashcards.length,
                        backgroundColor: AppTheme.surfaceColor,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                
                // Flashcard
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showAnswer = !_showAnswer);
                      },
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
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: AppTheme.borderRadiusLarge,
                            boxShadow: [
                              BoxShadow(
                                color: (_showAnswer ? const Color(0xFF8B5CF6) : AppTheme.primaryColor)
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _showAnswer ? 'Answer' : 'Question',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                _showAnswer
                                    ? _flashcards[_currentIndex]['answer']!
                                    : _flashcards[_currentIndex]['question']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.touch_app_rounded,
                                    color: Colors.white54,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showAnswer ? 'Tap to see question' : 'Tap to reveal answer',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Navigation Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentIndex > 0 ? _previousCard : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: _currentIndex > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.textLight,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentIndex < _flashcards.length - 1
                              ? _nextCard
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle',
                        onTap: () {},
                      ),
                      _ActionButton(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'Save',
                        onTap: () {},
                      ),
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'Reset',
                        onTap: () {
                          setState(() {
                            _currentIndex = 0;
                            _showAnswer = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
