import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'list_group_alerts.freezed.dart';

/// Nombre d'alertes de groupe montrées sur l'accueil par défaut.
const defaultGroupAlertLimit = 3;

/// Une alerte de groupe et le groupe qu'elle concerne.
@freezed
abstract class GroupAlertLine with _$GroupAlertLine {
  const factory GroupAlertLine({
    required GroupId groupId,
    required String groupName,
    required GroupAlert alert,
  }) = _GroupAlertLine;
}

/// Les alertes de groupe du club, limitées à l'affichage.
@freezed
abstract class GroupAlertList with _$GroupAlertList {
  const factory GroupAlertList({
    @Default(<GroupAlertLine>[]) List<GroupAlertLine> lines,

    /// Nombre total d'alertes (limite non appliquée).
    @Default(0) int total,
  }) = _GroupAlertList;
}

/// Cas d'usage : les alertes de groupe des groupes de la saison en cours.
@injectable
class ListGroupAlerts {
  ListGroupAlerts(
    this._groups,
    this._seasons,
    this._sessions,
    this._attempts,
    this._acquisitions,
    this._catalogue,
    this._config,
  );

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  Future<Result<GroupAlertList>> call({
    required DateTime today,
    int limit = defaultGroupAlertLimit,
  }) => runGuarded(() async {
    final catalogue = await _catalogue.load();
    final groups = currentGroups(
      await _groups.all(),
      currentSeasons: {
        for (final season in await _seasons.all())
          if (season.contains(today)) season.id,
      },
    );
    final attempts = await _attempts.all();
    final acquisitions = await _acquisitions.all();
    final lines = <GroupAlertLine>[];
    for (final group in groups) {
      final members = group.membersOn(today);
      final alerts = groupFailureAlerts(
        catalogue: catalogue,
        members: members,
        progress: {
          for (final id in members)
            id: StudentProgress.derive(
              studentId: id,
              attempts: attempts,
              acquisitions: acquisitions,
              rates: catalogue.rates,
              config: _config,
            ),
        },
        groupSessions: await _sessions.forGroup(group.id),
        asOf: today,
        config: _config,
      );
      lines.addAll([
        for (final alert in alerts)
          GroupAlertLine(
            groupId: group.id,
            groupName: group.name,
            alert: alert,
          ),
      ]);
    }
    final order = {
      for (final (index, block) in catalogue.blocks.indexed) block.id: index,
    };
    int teachingPosition(GroupAlertLine line) =>
        order[line.alert.blockId] ?? -1;
    // Part décroissante, puis nom du groupe, puis ordre d'enseignement.
    lines.sort((a, b) {
      final byShare = b.alert.sharePercent.compareTo(a.alert.sharePercent);
      if (byShare != 0) return byShare;
      final byGroup = a.groupName.compareTo(b.groupName);
      return byGroup != 0
          ? byGroup
          : teachingPosition(a).compareTo(teachingPosition(b));
    });
    return GroupAlertList(
      lines: List.unmodifiable(lines.take(limit)),
      total: lines.length,
    );
  });
}
