import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : planifier une nouvelle séance à une date, libre ou suivant
/// une séance du catalogue (`sheetId`), **pour un groupe** (ADR 0007, décision
/// du 2026-10-18 : le groupe est obligatoire).
///
/// Le public est celui du groupe et la date doit tomber dans sa saison
/// (`seasonOutsidePeriod`, comme l'ouverture d'une saisie) ; sans groupe,
/// `sessionNeedsGroup` ; un groupe inconnu est refusé (`unknownGroup`). Un
/// titre vide lève [InvalidSessionTitle]. Les séances sans groupe déjà
/// enregistrées (avant cette règle) restent lisibles : `Session.groupId` reste
/// facultatif à la lecture.
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
    GroupId? groupId,
    SheetId? sheetId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const InvalidSessionTitle();
    }
    if (cleanTitle.length > maxSessionTitleLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    if (groupId == null) {
      throw const InvariantViolation(InvariantCode.sessionNeedsGroup);
    }
    // La planification raisonne par jour : l'heure est ignorée, y compris
    // pour la borne de fin de saison.
    final day = date.dateOnly;
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
    final session = Session(
      id: _ids.next(),
      title: cleanTitle,
      date: day,
      audience: group.audience,
      groupId: groupId,
      sheetId: sheetId,
    );
    await _repository.add(session);
    return session;
  }
}
