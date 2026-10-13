import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';

/// Écrit le contenu d'une sauvegarde (section `data`) en structures JSON.
class BackupEncoder {
  const BackupEncoder();

  Map<String, Object?> encode(BackupSnapshot snapshot) => {
    'seasons': [for (final s in snapshot.seasons) _encodeSeason(s)],
    'students': [for (final s in snapshot.students) _encodeStudent(s)],
    'groups': [for (final g in snapshot.groups) _encodeGroup(g)],
    'sessionRecords': [
      for (final s in snapshot.sessionRecords) _encodeSessionRecord(s),
    ],
    'attempts': [for (final a in snapshot.attempts) _encodeAttempt(a)],
    'assessments': [for (final a in snapshot.assessments) _encodeAssessment(a)],
    'plannedSessions': [
      for (final s in snapshot.plannedSessions) _encodePlanned(s),
    ],
  };

  Map<String, Object?> _encodeSeason(Season season) => {
    'id': season.id.value,
    'label': season.label,
    'startDate': _date(season.startDate),
    'endDate': _date(season.endDate),
  };

  Map<String, Object?> _encodeStudent(Student student) => {
    'id': student.id.value,
    'firstName': student.firstName,
    'audienceHistory': [
      for (final change in student.audienceHistory)
        {
          'audience': change.audience.name,
          'effectiveFrom': _date(change.effectiveFrom),
        },
    ],
  };

  Map<String, Object?> _encodeGroup(Group group) => {
    'id': group.id.value,
    'seasonId': group.seasonId.value,
    'name': group.name,
    'audience': group.audience.name,
    'memberships': [
      for (final m in group.memberships)
        {
          'studentId': m.studentId.value,
          'from': _date(m.from),
          'to': m.to == null ? null : _date(m.to!),
        },
    ],
  };

  Map<String, Object?> _encodeSessionRecord(SessionRecord record) => {
    'id': record.id.value,
    'groupId': record.groupId.value,
    'seasonId': record.seasonId.value,
    'date': _date(record.date),
    'audience': record.audience.name,
    'present': [for (final id in record.present) id.value],
    'mainBlockId': record.mainBlockId,
    'recallBlockId': record.recallBlockId,
  };

  Map<String, Object?> _encodeAttempt(ExerciseAttempt attempt) => {
    'id': attempt.id.value,
    'studentId': attempt.studentId.value,
    'sessionId': attempt.sessionId.value,
    'blockId': attempt.exercise.blockId,
    'exerciseNumber': attempt.exercise.number,
    'date': _date(attempt.date),
    'passIndex': attempt.passIndex,
    'potted': attempt.potted,
    'total': attempt.total,
  };

  Map<String, Object?> _encodeAssessment(MaturityAssessment assessment) => {
    'id': assessment.id.value,
    'studentId': assessment.studentId.value,
    'date': _date(assessment.date),
    'concentration': assessment.concentration,
    'endurance': assessment.endurance,
    'frustration': assessment.frustration,
    'comment': assessment.comment,
  };

  Map<String, Object?> _encodePlanned(Session session) => {
    'id': session.id,
    'title': session.title,
    'audience': session.audience.name,
    'sheetId': session.sheetId?.value,
  };

  String _date(DateTime value) => value.toIso8601String();
}
