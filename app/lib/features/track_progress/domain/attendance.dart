import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Assiduité de [studentId] (ADR 0006) : une séance compte si son groupe le
/// compte membre à sa date (`Group.isMemberOn`) ; elle est suivie s'il y est
/// présent.
Attendance attendanceOf({
  required StudentId studentId,
  required List<SessionRecord> sessions,
  required List<Group> groups,
}) {
  final byId = {for (final group in groups) group.id: group};
  return attendanceFrom([
    for (final session in sessions)
      if (byId[session.groupId]?.isMemberOn(studentId, session.date) ?? false)
        session.present.contains(studentId),
  ]);
}
