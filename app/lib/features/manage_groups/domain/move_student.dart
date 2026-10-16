import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : déplacer un élève dans un autre groupe de la même saison et
/// du même public, à partir du jour `on`. Un élève qui n'appartient à aucun
/// groupe est simplement placé dans le groupe choisi (il reste réaffectable
/// après une clôture sans reconduction, ou s'il a quitté son groupe).
///
/// L'appartenance ouverte est close la veille de `on`, l'autre s'ouvre à
/// `on` : aucune période ne se chevauche. `on` doit être strictement
/// postérieure au début de l'appartenance et au dernier jour de présence de
/// l'élève dans le groupe d'origine (`moveBeforeLastPresence`) : on ne
/// réécrit pas une séance saisie, et dans la saison (`seasonOutsidePeriod`).
/// Rien n'est copié : les passages suivent l'élève, les présences restent aux
/// séances. Changer de public reste `ChangeAudience`.
@injectable
class MoveStudent {
  MoveStudent(
    this._students,
    this._groups,
    this._seasons,
    this._sessions,
    this._unitOfWork,
  );

  final StudentRepository _students;
  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final SessionRecordRepository _sessions;
  final UnitOfWork _unitOfWork;

  /// Le groupe de destination après déplacement.
  Future<Result<Group>> call({
    required StudentId studentId,
    required GroupId toGroupId,
    required DateTime on,
  }) => runGuarded(() async {
    final student = await _students.byId(studentId);
    if (student == null) throw NotFound('student', studentId.value);
    final destination = await _groups.byId(toGroupId);
    if (destination == null) throw NotFound('group', toGroupId.value);
    final day = on.dateOnly;
    final groups = await _groups.all();
    // L'appartenance restée ouverte dans une saison close n'en est plus une.
    final closed = {
      for (final season in await _seasons.all())
        if (season.isClosed) season.id,
    };
    final origin = groups
        .where(
          (g) =>
              !closed.contains(g.seasonId) &&
              g.memberships.any(
                (m) => m.studentId == studentId && m.to == null,
              ),
        )
        .firstOrNull;
    if (origin != null) {
      if (origin.seasonId != destination.seasonId) {
        throw InvariantViolation(InvariantCode.unknownGroup, toGroupId.value);
      }
      if (origin.id == destination.id) {
        throw const InvariantViolation(InvariantCode.membershipAlreadyOpen);
      }
    }
    // Un élève sans groupe se replace : le public du groupe choisi doit être
    // le sien ce jour-là.
    final audience = origin?.audience ?? student.audienceAt(day);
    if (destination.audience != audience) {
      throw const InvariantViolation(InvariantCode.audienceMismatch);
    }
    final season = await _seasons.byId(destination.seasonId);
    if (season == null) throw NotFound('season', destination.seasonId.value);
    if (season.isClosed) {
      throw const InvariantViolation(InvariantCode.seasonClosed);
    }
    if (day.isAfter(season.endDate)) {
      throw const InvariantViolation(InvariantCode.seasonOutsidePeriod);
    }
    var floor = _floor(origin, groups, destination.seasonId, studentId);
    if (origin != null) {
      for (final session in await _sessions.forGroup(origin.id)) {
        if (session.present.contains(studentId) &&
            session.date.dateOnly.isAfter(floor)) {
          floor = session.date.dateOnly;
        }
      }
    }
    if (!day.isAfter(floor)) {
      throw const InvariantViolation(InvariantCode.moveBeforeLastPresence);
    }
    final released = origin?.release(
      studentId: studentId,
      to: DateTime(day.year, day.month, day.day - 1),
    );
    final admitted = destination.admit(
      studentId: studentId,
      studentAudience: destination.audience,
      from: day,
    );
    await _unitOfWork.run(() async {
      if (released != null) await _groups.save(released);
      await _groups.save(admitted);
    });
    return admitted;
  });

  /// Dernier jour déjà « pris » par l'élève : le début de son appartenance
  /// ouverte dans [origin], ou, sans groupe, la fin de sa dernière
  /// appartenance dans un groupe de la saison [seasonId].
  DateTime _floor(
    Group? origin,
    List<Group> groups,
    SeasonId seasonId,
    StudentId studentId,
  ) {
    if (origin != null) {
      return origin.memberships
          .firstWhere((m) => m.studentId == studentId && m.to == null)
          .from
          .dateOnly;
    }
    var latest = DateTime(0);
    for (final group in groups.where((g) => g.seasonId == seasonId)) {
      for (final m in group.memberships) {
        final end = m.to?.dateOnly;
        if (m.studentId == studentId && end != null && end.isAfter(latest)) {
          latest = end;
        }
      }
    }
    return latest;
  }
}
