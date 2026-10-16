import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_attendance.freezed.dart';

/// Une séance du groupe : présents sur présents possibles.
@freezed
abstract class SessionAttendance with _$SessionAttendance {
  const factory SessionAttendance({
    required DateTime date,
    required int present,
    required int possible,
  }) = _SessionAttendance;
}

/// Assiduité d'un groupe : présences cumulées sur les présences possibles,
/// sur toutes les séances saisies du groupe jusqu'à un jour donné.
@freezed
abstract class GroupAttendance with _$GroupAttendance {
  const factory GroupAttendance({
    required int present,
    required int possible,
    required int sessionCount,

    /// Les dernières séances, la plus récente d'abord.
    required List<SessionAttendance> recent,

    /// Assiduité de chaque membre (tout élève ayant une appartenance au
    /// groupe), sur les mêmes séances.
    @Default(<StudentId, Attendance>{}) Map<StudentId, Attendance> members,
  }) = _GroupAttendance;

  const GroupAttendance._();

  /// Aucune séance saisie : on ne présente pas « 0 % ».
  bool get isEmpty => sessionCount == 0;

  /// Taux en pourcentage entier (arrondi) ; `null` sans présence possible.
  int? get percent => possible == 0 ? null : (present * 100 / possible).round();
}

/// Nombre de séances listées dans [GroupAttendance.recent].
const recentAttendanceCount = 5;

/// Assiduité de [group] sur les [sessions] datées au plus tard à [asOf].
GroupAttendance groupAttendance({
  required List<SessionRecord> sessions,
  required Group group,
  required DateTime asOf,
}) {
  final cutoff = asOf.dateOnly;
  final counted = [
    for (final session in sessions)
      if (session.groupId == group.id && !session.date.dateOnly.isAfter(cutoff))
        session,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final everyone = {for (final m in group.memberships) m.studentId};
  final perSession = [
    for (final session in counted)
      () {
        final possible = [
          for (final student in everyone)
            if (group.isMemberOn(student, session.date)) student,
        ];
        return SessionAttendance(
          date: session.date,
          present: possible.where(session.present.contains).length,
          possible: possible.length,
        );
      }(),
  ];
  return GroupAttendance(
    members: Map.unmodifiable({
      for (final student in everyone)
        student: attendanceFrom([
          for (final session in counted)
            if (group.isMemberOn(student, session.date))
              session.present.contains(student),
        ]),
    }),
    present: perSession.fold(0, (sum, line) => sum + line.present),
    possible: perSession.fold(0, (sum, line) => sum + line.possible),
    sessionCount: perSession.length,
    recent: List.unmodifiable(perSession.reversed.take(recentAttendanceCount)),
  );
}
