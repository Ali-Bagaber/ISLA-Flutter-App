class QuizItem {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizItem({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class FlashcardItem {
  final String front;
  final String back;

  const FlashcardItem({
    required this.front,
    required this.back,
  });
}

class StudyAidSet {
  final String sessionId;
  final String summary;
  final List<FlashcardItem> flashcards;
  final List<QuizItem> quizItems;
  final DateTime generatedAt;

  const StudyAidSet({
    required this.sessionId,
    required this.summary,
    required this.flashcards,
    required this.quizItems,
    required this.generatedAt,
  });
}
