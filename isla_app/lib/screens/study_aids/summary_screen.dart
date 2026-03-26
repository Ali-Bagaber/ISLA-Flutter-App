import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class SummaryScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const SummaryScreen({super.key, required this.document});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    // Simulate AI generation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    });
  }

  final String _mockSummary = '''
**Key Points Summary**

1. **Introduction to Data Structures**
   Data structures are fundamental concepts in computer science that enable efficient organization, storage, and manipulation of data. Understanding these concepts is crucial for developing optimized algorithms.

2. **Types of Data Structures**
   - Linear: Arrays, Linked Lists, Stacks, Queues
   - Non-linear: Trees, Graphs, Hash Tables
   - Each type has specific use cases and performance characteristics

3. **Time Complexity Analysis**
   Big O notation is used to describe the performance of algorithms:
   - O(1): Constant time
   - O(log n): Logarithmic time
   - O(n): Linear time
   - O(n²): Quadratic time

4. **Applications**
   - Database indexing uses B-trees
   - Network routing uses graphs
   - Memory management uses linked lists
   - Expression evaluation uses stacks

5. **Best Practices**
   - Choose appropriate data structure based on operations needed
   - Consider space vs time trade-offs
   - Understand the problem domain before implementation
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Summary'),
        actions: [
          if (!_isGenerating)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          if (!_isGenerating)
            IconButton(icon: const Icon(Icons.share_rounded), onPressed: () {}),
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
                      color: AppTheme.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppTheme.success),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Generating Summary...', style: AppTheme.headingSmall),
                  const SizedBox(height: 8),
                  Text(
                    'AI is analyzing your document',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: AppTheme.borderRadiusMedium,
                      border: Border.all(
                        color: AppTheme.success.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary Generated',
                                style: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.success,
                                ),
                              ),
                              Text(
                                widget.document['title'],
                                style: AppTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Summary Stats
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.article_outlined,
                        label: '5 Key Points',
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: '3 min read',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Summary Content
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.borderRadiusLarge,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Text(
                      _mockSummary,
                      style: AppTheme.bodyMedium.copyWith(height: 1.6),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Regenerate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}
