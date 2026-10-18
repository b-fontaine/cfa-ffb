import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/sitting_id.dart';
import 'package:billard_cfa/features/record_results/domain/resolve_sheet_blocks.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : ouvrir la séance d'un groupe à une date, avec ses présents.
///
/// Avec une séance du catalogue `sheetId`, la notion principale et le rappel
/// de résultats **non fournis** en sont dérivés (`SheetBlocks.resolve`, ADR
/// 0007).
///
/// Identité (ADR 0016 amendé, ADR 0024 décision 18) : une saisie liée à une
/// séance du catalogue reçoit l'identifiant déterministe `sittingId` ; une
/// saisie libre, un UUID. Si cette saisie existe déjà (même un autre appareil
/// l'ouvre au même moment), elle est reprise : ses étiquettes et ses blocs
/// restent, les présents s'ajoutent (`SessionRecordRepository.open`).
@injectable
class OpenSession {
  OpenSession(
    this._groups,
    this._seasons,
    this._sessions,
    this._catalogue,
    this._sheetBlocks,
    this._ids,
  );

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final SessionRecordRepository _sessions;
  final CatalogueRepository _catalogue;
  final ResolveSheetBlocks _sheetBlocks;
  final IdGenerator _ids;

  Future<Result<SessionRecord>> call({
    required GroupId groupId,
    required DateTime date,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,
    SheetId? sheetId,
  }) => runGuarded(() async {
    requirePresentFit(present);
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final season = await _seasons.byId(group.seasonId);
    if (season == null) throw NotFound('season', group.seasonId.value);
    if (season.isClosed) {
      throw const InvariantViolation(InvariantCode.seasonClosed);
    }
    if (!season.contains(date)) {
      throw const InvariantViolation(InvariantCode.seasonOutsidePeriod);
    }
    if (!present.every((student) => group.isMemberOn(student, date))) {
      throw const InvariantViolation(InvariantCode.studentNotInGroup);
    }
    final (:main, :recall) = (await _sheetBlocks(sheetId))
        .resolve(main: mainBlockId, recall: recallBlockId);
    final catalogue = await _catalogue.load();
    final blocks = [main, recall].nonNulls;
    if (blocks.any((id) => catalogue.blockById(id) == null)) {
      throw const InvariantViolation(InvariantCode.unknownBlock);
    }
    final id = sheetId == null
        ? SessionId(_ids.next())
        : sittingId(groupId, date, sheetId);
    final session = SessionRecord(
      id: id,
      groupId: groupId,
      seasonId: season.id,
      date: date,
      audience: group.audience,
      present: present,
      mainBlockId: main,
      recallBlockId: recall,
      sheetId: sheetId,
    );
    // Création si l'identifiant est libre, sinon reprise sans rien effacer :
    // un autre appareil a pu ouvrir la même séance entre-temps (décision 18),
    // le dépôt tranche de façon atomique.
    return await _sessions.open(session);
  });
}
