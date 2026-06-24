import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/gemini_study_service.dart';
import '../../services/unsplash_service.dart';

class FlashcardsScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const FlashcardsScreen({super.key, required this.document});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

enum _Confidence { know, unsure, dontKnow }

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool _isGenerating = true;
  String? _error;
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Map<String, String>> _allCards = [];
  List<Map<String, String>> _deck = [];        // current deck being studied
  Map<int, _Confidence> _confidence = {};      // deck-index → confidence
  int _firstRoundKnown = 0;                    // cards known on first attempt
  int _reviewRounds = 0;                       // how many review rounds needed
  bool _inReviewMode = false;
  bool _sessionComplete = false;
  String _loadingMessage = 'Generating flashcards...';
  bool _cancelled = false;
  final _service = GeminiStudyService();
  static const _totalCards = 8;
  final Map<String, UnsplashPhoto?> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _currentIndex = 0;
      _showAnswer = false;
      _allCards = [];
      _deck = [];
      _confidence = {};
      _firstRoundKnown = 0;
      _reviewRounds = 0;
      _inReviewMode = false;
      _sessionComplete = false;
      _cancelled = false;
      _loadingMessage = 'Generating flashcards...';
    });

    try {
      final cards = await _service.generateFlashcards(
        title: widget.document['title'] ?? 'Unknown Document',
        subject: widget.document['subject'] ?? 'General',
        count: _totalCards,
        documentText: (widget.document['extractedText'] ??
                widget.document['notes'] ??
                widget.document['content'] ??
                widget.document['description'] ??
                '')
            .toString(),
        onRetrying: () {
          if (mounted) {
            setState(() => _loadingMessage =
                'AI is busy — retrying automatically, please wait...');
          }
        },
      );
      if (_cancelled || !mounted) return;
      setState(() {
        _allCards = cards;
        _deck = List.from(cards);
        _isGenerating = false;
      });
      _fetchPhotos(cards);
      GeminiStudyService.saveFlashcards(
        title: widget.document['title'] ?? '',
        subject: widget.document['subject'] ?? '',
        cards: cards,
        documentId:
            widget.document['id'] ?? widget.document['documentId'] ?? '',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e
              .toString()
              .replaceAll('StateError: ', '')
              .replaceAll('Bad state: ', '');
          _isGenerating = false;
        });
      }
    }
  }

  void _fetchPhotos(List<Map<String, String>> cards) {
    for (final card in cards) {
      final keyword = card['imageKeyword'] ?? '';
      if (keyword.isEmpty || _photoCache.containsKey(keyword)) continue;
      _photoCache[keyword] = null;
      UnsplashService.fetchPhoto(keyword).then((photo) {
        if (mounted && photo != null) {
          setState(() => _photoCache[keyword] = photo);
        }
      });
    }
  }

  void _rate(_Confidence rating) {
    setState(() {
      _confidence[_currentIndex] = rating;
      _showAnswer = false;
      if (_currentIndex < _deck.length - 1) {
        _currentIndex++;
      } else {
        _finishDeck();
      }
    });
  }

  void _finishDeck() {
    final needReview = <Map<String, String>>[];
    var roundKnows = 0;
    for (var i = 0; i < _deck.length; i++) {
      final c = _confidence[i];
      if (c == _Confidence.know) {
        roundKnows++;
      } else {
        needReview.add(_deck[i]);
      }
    }
    if (!_inReviewMode) _firstRoundKnown = roundKnows;

    if (needReview.isEmpty) {
      _confidence = {};
      _sessionComplete = true;
    } else {
      _reviewRounds++;
      _deck = needReview;
      _currentIndex = 0;
      _confidence = {};
      _inReviewMode = true;
    }
  }

  void _restart() {
    setState(() {
      _deck = List.from(_allCards);
      _currentIndex = 0;
      _showAnswer = false;
      _confidence = {};
      _firstRoundKnown = 0;
      _reviewRounds = 0;
      _inReviewMode = false;
      _sessionComplete = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: Text(_inReviewMode ? 'Review Round' : 'AI Flashcards'),
        actions: [
          if (!_isGenerating && _deck.isNotEmpty && !_sessionComplete)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_deck.length}',
                  style: AppTheme.labelMedium
                      .copyWith(color: AppTheme.primaryColor),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: _isGenerating
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _sessionComplete
                    ? _buildComplete(isDark)
                    : _buildCard(isDark),
      ),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Generating Flashcards...', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text(_loadingMessage,
                style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 44),
              const SizedBox(height: 16),
              Text(_error!,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildComplete(bool isDark) {
    final total = _allCards.length;
    final firstPct = total > 0 ? (_firstRoundKnown / total * 100).round() : 0;
    final textSecondary = AppTheme.getTextSecondary(isDark);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 46, color: AppTheme.success),
          ),
          const SizedBox(height: 24),
          Text('All Cards Mastered!', style: AppTheme.headingLarge),
          const SizedBox(height: 8),
          Text('You reviewed all $total cards',
              style: AppTheme.bodyMedium
                  .copyWith(color: textSecondary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(isDark),
              borderRadius: AppTheme.borderRadiusLarge,
              boxShadow: isDark ? [] : AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text('$firstPct%',
                    style: AppTheme.headingLarge.copyWith(
                        fontSize: 42, color: AppTheme.success)),
                const SizedBox(height: 4),
                Text('First-try accuracy',
                    style: AppTheme.bodySmall.copyWith(color: textSecondary)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.check_circle_rounded,
                        iconColor: AppTheme.success,
                        value: '$_firstRoundKnown / $total',
                        label: 'Known first try',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: _reviewRounds == 0
                            ? Icons.star_rounded
                            : Icons.replay_rounded,
                        iconColor: _reviewRounds == 0
                            ? AppTheme.warning
                            : AppTheme.primaryColor,
                        value: _reviewRounds == 0
                            ? 'Perfect!'
                            : '$_reviewRounds',
                        label: _reviewRounds == 0
                            ? 'No review needed'
                            : 'Review round${_reviewRounds == 1 ? '' : 's'}',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Study Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark) {
    final card = _deck[_currentIndex];
    return Column(
      children: [
        // ── Progress bar ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _inReviewMode
                          ? 'Reviewing ${_deck.length} cards'
                          : (widget.document['title'] ?? ''),
                      style: AppTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${((_currentIndex + 1) / _deck.length * 100).toInt()}%',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _deck.length,
                backgroundColor: AppTheme.surfaceColor,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primaryColor),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // ── Card ────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Container(
                  key: ValueKey<String>(
                      '${_currentIndex}_$_showAnswer'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: _showAnswer
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryLight
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: AppTheme.borderRadiusLarge,
                    boxShadow: [
                      BoxShadow(
                        color: (_showAnswer
                                ? const Color(0xFF6366F1)
                                : AppTheme.primaryColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Builder(builder: (context) {
                    final keyword = card['imageKeyword'] ?? '';
                    final photo = keyword.isNotEmpty ? _photoCache[keyword] : null;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
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
                        if (photo != null && photo.url.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: photo.url,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(photo.photographerUrl)),
                            child: Text(
                              'Photo by ${photo.photographerName} on Unsplash',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Text(
                                _showAnswer
                                    ? (card['answer'] ?? '')
                                    : (card['question'] ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_rounded,
                                color: Colors.white54, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              _showAnswer
                                  ? 'Tap to see question'
                                  : 'Tap to reveal answer',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),

        // ── Confidence buttons (shown after answer is revealed) ─────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showAnswer
              ? Padding(
                  key: const ValueKey('confidence'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      Text(
                        'How well did you know this?',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ConfidenceButton(
                            label: "Don't Know",
                            icon: Icons.close_rounded,
                            color: AppTheme.error,
                            onTap: () => _rate(_Confidence.dontKnow),
                          ),
                          const SizedBox(width: 8),
                          _ConfidenceButton(
                            label: 'Almost',
                            icon: Icons.remove_rounded,
                            color: AppTheme.warning,
                            onTap: () => _rate(_Confidence.unsure),
                          ),
                          const SizedBox(width: 8),
                          _ConfidenceButton(
                            label: 'Know It',
                            icon: Icons.check_rounded,
                            color: AppTheme.success,
                            onTap: () => _rate(_Confidence.know),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Padding(
                  key: const ValueKey('hint'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    'Tap the card to reveal the answer',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ConfidenceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ConfidenceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: AppTheme.headingSmall
                  .copyWith(color: AppTheme.getTextPrimary(isDark))),
          const SizedBox(height: 2),
          Text(label,
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.getTextSecondary(isDark), fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
