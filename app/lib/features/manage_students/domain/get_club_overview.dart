import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
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
    this._catalogue,
    this._config,
  );

  final GroupRepository _groups;
  final StudentRepository _students;
  final SeasonRepository _seasons;
  final AttemptRepository _attempts;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<ClubOverview>> call({required DateTime today}) =>
      runGuarded(() async {
        final catalogue = await _catalogue.load();
        final attempts = await _attempts.all();
        final current = {
          for (final season in await _seasons.all())
            if (season.contains(today)) season.id,
        };
        final every = await _groups.all();
        final groups = current.isEmpty
            ? every
            : [
                for (final group in every)
                  if (current.contains(group.seasonId)) group,
              ];
        final summaries = [
          for (final student in await _students.all())
            () {
              final progress = StudentProgress.derive(
                studentId: student.id,
                attempts: attempts,
                rates: catalogue.rates,
                config: _config,
              );
              return StudentSummary(
                student: student,
                validatedCount: progress.validated.length,
                exerciseCount: catalogue.exercises.length,
                alertCount: progress.activeAlerts.length,
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
                  if (_isCurrentMember(group, summary, today)) summary,
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
      });

  bool _isCurrentMember(Group group, StudentSummary summary, DateTime today) =>
      group.isMemberOn(summary.student.id, today);
}
