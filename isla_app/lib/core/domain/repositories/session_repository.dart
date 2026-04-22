import '../models/checklist_item.dart';
import '../models/pomodoro_run.dart';
import '../models/study_aid_set.dart';
import '../models/study_material.dart';
import '../models/study_session.dart';

abstract class SessionRepository {
  Future<List<StudySession>> getSessions();
  Future<StudySession?> getSessionById(String id);
  Future<void> createSession(StudySession session);
  Future<void> updateSession(StudySession session);
  Future<void> saveChecklistItems(List<ChecklistItem> items);
  Future<List<ChecklistItem>> getChecklistItems(String sessionId);
  Future<void> savePomodoroRun(PomodoroRun run);
  Future<List<PomodoroRun>> getPomodoroRuns(String sessionId);
  Future<void> saveStudyMaterials(List<StudyMaterial> materials);
  Future<List<StudyMaterial>> getStudyMaterials(String sessionId);
  Future<void> saveStudyAidSet(StudyAidSet aids);
  Future<StudyAidSet?> getStudyAidSet(String sessionId);
}
