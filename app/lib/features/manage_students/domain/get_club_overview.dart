import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les groupes de la saison en cours (ou tous si aucune saison
/// ne contient `today`), leurs membres du jour et leur progression.
@injectable
class GetClubOverview {
  GetClubOverview(
    this._groups,
    this._students,
    this._seasons,
    this._attempts,
    this._acquisitions,
    this._acknowledgements,
    this._catalogue,
    this._config,
  );

  final GroupRepository _groups;
  final StudentRepository _students;
  final SeasonRepository _seasons;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final AcknowledgementRepository _acknowledgements;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<ClubOverview>> call({required DateTime today}) => runGuarded(
    () async {
      final catalogue = await _catalogue.load();
      final attempts = await _attempts.all();
      final acquisitions = await _acquisitions.all();
      final acknowledgements = await _acknowledgements.all();
      final seasons = await _seasons.all();
      final groups = currentGroups(
        await _groups.all(),
        currentSeasons: {
          for (final season in seasons)
            if (season.isOpenOn(today)) season.id,
        },
        closedSeasons: {
          for (final season in seasons)
            if (season.isClosed) season.id,
        },
      );
      // Une saison préparée (après une clôture) montre son effectif au
      // premier jour, pas « personne » : ses élèves ne sont pas « sans
      // groupe » pendant l'été.
      final startOf = {for (final season in seasons) season.id: season};
      DateTime rosterDay(Group group) {
        final start = startOf[group.seasonId]?.startDate;
        return start != null && start.isAfter(today) ? start : today;
      }

      final summaries = [
        for (final student in await _students.all())
          () {
            final progress = StudentProgress.derive(
              studentId: student.id,
              attempts: attempts,
              acquisitions: acquisitions,
              acknowledgements: acknowledgements,
              rates: catalogue.rates,
              config: _config,
            );
            return StudentSummary(
              student: student,
              validatedCount: progress.validated.length,
              exerciseCount: catalogue.exercises.length,
              alertCount: progress.activeAlerts.length,
              toStart: progress.toStart,
            );
          }(),
      ];
      final placed = <StudentSummary>{};
      final overviews = [
        for (final group in groups)
          GroupOverview(
            group: group,
            members: [
              for (final summary in summaries)
                if (_isCurrentMember(group, summary, rosterDay(group))) summary,
            ],
          ),
      ];
      for (final overview in overviews) {
        placed.addAll(overview.members);
      }
      return ClubOverview(
        groups: overviews,
        unassigned: [
          for (final summary in summaries)
            if (!placed.contains(summary)) summary,
        ],
      );
    },
  );

  bool _isCurrentMember(Group group, StudentSummary summary, DateTime today) =>
      group.isMemberOn(summary.student.id, today);
}
