import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance.freezed.dart';

/// Assiduité d'un élève : séances où il était présent sur les séances de ses
/// groupes aux dates où il en était membre (ADR 0006).
@freezed
abstract class Attendance with _$Attendance {
  const factory Attendance({required int attended, required int total}) =
      _Attendance;

  const Attendance._();

  /// Aucune séance de groupe à compter.
  bool get isEmpty => total == 0;
}

/// Assiduité de [studentId] : une séance compte si son groupe le compte
/// membre à sa date (`Group.isMemberOn`) ; elle est suivie s'il y est présent.
Attendance attendanceOf({
  required StudentId studentId,
  required List<SessionRecord> sessions,
  required List<Group> groups,
}) {
  final byId = {for (final group in groups) group.id: group};
  var total = 0;
  var attended = 0;
  for (final session in sessions) {
    final group = byId[session.groupId];
    if (group == null || !group.isMemberOn(studentId, session.date)) continue;
    total++;
    if (session.present.contains(studentId)) attended++;
  }
  return Attendance(attended: attended, total: total);
}
