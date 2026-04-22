class ChecklistItem {
  final String id;
  final String sessionId;
  final String title;
  final int sortOrder;
  final bool isCompleted;
  final DateTime? completedAt;

  const ChecklistItem({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.sortOrder,
    required this.isCompleted,
    this.completedAt,
  });
}
