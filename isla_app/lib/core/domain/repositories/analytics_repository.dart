class AnalyticsSnapshot {
  final int totalFocusMinutes;
  final int completedSessions;
  final int completedTasks;
  final int pendingTasks;
  final Map<String, int> subjectFocusMinutes;

  const AnalyticsSnapshot({
    required this.totalFocusMinutes,
    required this.completedSessions,
    required this.completedTasks,
    required this.pendingTasks,
    required this.subjectFocusMinutes,
  });

  double get completionRate {
    final total = completedTasks + pendingTasks;
    if (total == 0) {
      return 0;
    }
    return completedTasks / total;
  }
}

abstract class AnalyticsRepository {
  Future<AnalyticsSnapshot> loadSnapshot();
}
