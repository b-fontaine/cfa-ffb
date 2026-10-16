import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/features/track_group/domain/group_attendance.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/shared/lib/attendance.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la grille d'un groupe (technique × élève), son assiduité et
/// ses alertes de groupe.
@injectable
class GetGroupOverview {
  GetGroupOverview(
    this._groups,
    this._students,
    this._seasons,
    this._sessions,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._catalogue,
    this._config,
  );

  final GroupRepository _groups;
  final StudentRepository _students;
  final SeasonRepository _seasons;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  /// [today] borne l'assiduité et fixe les membres (colonnes) du jour ; pour
  /// une saison qui n'a pas commencé, les colonnes sont celles de son premier
  /// jour (saison préparée par une clôture).
  Future<Result<GroupGrid>> call({
    required GroupId groupId,
    required DateTime today,
  }) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final catalogue = await _catalogue.load();
    final start = (await _seasons.byId(group.seasonId))?.startDate;
    final rosterDay = start != null && start.isAfter(today) ? start : today;
    final everyone = {
      for (final student in await _students.all()) student.id: student,
    };
    final members =
        [
          for (final id in group.membersOn(rosterDay))
            if (everyone[id] != null) everyone[id]!,
        ]..sort((a, b) {
          final byName = a.firstName.toLowerCase().compareTo(
            b.firstName.toLowerCase(),
          );
          return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
        });
    final attempts = await _attempts.all();
    final acquisitions = await _acquisitions.all();
    final acknowledgements = await _acknowledgements.all();
    // Mêmes membres que les alertes de l'accueil (`ListGroupAlerts`) : tous
    // les identifiants du groupe au jour donné, connus ou non.
    final memberIds = group.membersOn(rosterDay);
    final progress = {
      for (final id in memberIds)
        id: StudentProgress.derive(
          studentId: id,
          attempts: attempts,
          acquisitions: acquisitions,
          acknowledgements: acknowledgements,
          rates: catalogue.rates,
          config: _config,
        ),
    };
    final sessions = await _sessions.forGroup(groupId);
    final attendance = groupAttendance(
      sessions: sessions,
      group: group,
      asOf: today,
    );
    return GroupGrid(
      groupId: groupId,
      name: group.name,
      students: [
        for (final student in members)
          GridStudent(
            id: student.id,
            firstName: student.firstName,
            attendance:
                attendance.members[student.id] ??
                const Attendance(attended: 0, total: 0),
          ),
      ],
      rows: [
        for (final block in catalogue.blocks)
          GridRow(
            technique: GridTechnique(
              blockId: block.id,
              title: block.title,
              proposal: block.isProposal,
              exerciseCount: block.exercises.length,
            ),
            cells: [
              for (final student in members)
                () {
                  final summary = techniqueSummary(
                    blockId: block.id,
                    exercises: block.exerciseRefs,
                    progress: progress[student.id]!,
                  );
                  return GridCell(
                    studentId: student.id,
                    status: summary.status,
                    doneCount: summary.doneCount,
                    total: summary.total,
                    alerted: summary.alerted > 0,
                  );
                }(),
            ],
          ),
      ],
      attendance: attendance,
      alerts: groupFailureAlerts(
        catalogue: catalogue,
        members: memberIds,
        progress: progress,
        groupSessions: sessions,
        asOf: today,
        config: _config,
      ),
    );
  });
}
