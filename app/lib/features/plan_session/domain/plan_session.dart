import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : planifier une nouvelle séance à une date, libre ou suivant
/// une séance du catalogue (`sheetId`), pour un groupe ou sans (ADR 0007).
///
/// Avec un groupe, le public est celui du groupe et la date doit tomber dans
/// sa saison (`seasonOutsidePeriod`, comme l'ouverture d'une saisie) ; un
/// groupe inconnu est refusé (`unknownGroup`). Sans groupe, `audience` est
/// pris tel quel. Un titre vide lève [InvalidSessionTitle].
@injectable
class PlanSession {
  PlanSession(this._repository, this._groups, this._seasons, this._ids);

  final SessionRepository _repository;
  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final IdGenerator _ids;

  Future<Session> call({
    required String title,
    required DateTime date,
    required Audience audience,
    SheetId? sheetId,
    GroupId? groupId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidSessionTitle();
    }
    // La planification raisonne par jour : l'heure est ignorée, y compris
    // pour la borne de fin de saison.
    final day = date.dateOnly;
    var resolvedAudience = audience;
    if (groupId != null) {
      final group = await _groups.byId(groupId);
      if (group == null) {
        throw InvariantViolation(InvariantCode.unknownGroup, groupId.value);
      }
      final season = await _seasons.byId(group.seasonId);
      if (season == null) throw NotFound('season', group.seasonId.value);
      if (season.isClosed) {
        throw const InvariantViolation(InvariantCode.seasonClosed);
      }
      if (!season.contains(day)) {
        throw const InvariantViolation(InvariantCode.seasonOutsidePeriod);
      }
      resolvedAudience = group.audience;
    }
    final session = Session(
      id: _ids.next(),
      title: cleanTitle,
      date: day,
      audience: resolvedAudience,
      groupId: groupId,
      sheetId: sheetId,
    );
    await _repository.add(session);
    return session;
  }
}
