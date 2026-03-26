// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudySession _$StudySessionFromJson(Map<String, dynamic> json) => StudySession(
      id: json['id'] as String,
      subject: json['subject'] as String,
      studyGoal: json['studyGoal'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      plannedDuration: (json['plannedDuration'] as num).toInt(),
      actualDuration: (json['actualDuration'] as num?)?.toInt() ?? 0,
      pomodoroSessions: (json['pomodoroSessions'] as num?)?.toInt() ?? 0,
      checklistIds: (json['checklistIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      status: $enumDecodeNullable(_$SessionStatusEnumMap, json['status']) ??
          SessionStatus.ongoing,
      completedTasks: (json['completedTasks'] as num?)?.toInt() ?? 0,
      totalTasks: (json['totalTasks'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$StudySessionToJson(StudySession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'studyGoal': instance.studyGoal,
      'createdAt': instance.createdAt.toIso8601String(),
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'plannedDuration': instance.plannedDuration,
      'actualDuration': instance.actualDuration,
      'pomodoroSessions': instance.pomodoroSessions,
      'checklistIds': instance.checklistIds,
      'status': _$SessionStatusEnumMap[instance.status]!,
      'completedTasks': instance.completedTasks,
      'totalTasks': instance.totalTasks,
    };

const _$SessionStatusEnumMap = {
  SessionStatus.ongoing: 'ongoing',
  SessionStatus.paused: 'paused',
  SessionStatus.completed: 'completed',
  SessionStatus.abandoned: 'abandoned',
};
