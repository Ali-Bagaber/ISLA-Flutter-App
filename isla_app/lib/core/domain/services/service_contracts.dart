import '../models/checklist_item.dart';
import '../models/study_aid_set.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<void> schedulePhaseEndNotification({
    required String runId,
    required DateTime phaseEndAt,
    required bool isBreak,
  });
  Future<void> cancelNotification(String runId);
}

abstract class GeminiService {
  Future<List<ChecklistItem>> generateChecklist({
    required String sessionId,
    required String goal,
    required String sourceText,
  });

  Future<StudyAidSet> generateStudyAids({
    required String sessionId,
    required String goal,
    required String sourceText,
    required List<String> finalChecklist,
  });
}

abstract class StudyMaterialParser {
  Future<String> parsePdf(String localPath);
  Future<String> parsePptx(String localPath);
}
