import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/record_matching.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/resolve_sheet_blocks.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : ouvrir la séance d'un groupe à une date, ou la reprendre si
/// elle existe déjà ce jour-là **pour la même séance du catalogue** (les
/// passages déjà saisis sont conservés, les présents sont mis à jour). Évite
/// les séances en double quand l'animateur revient sur la saisie, mais une
/// autre séance du catalogue le même jour ouvre sa propre saisie sans toucher
/// à la première (règle `recordFor`, ADR 0016).
///
/// À la reprise, la séance du catalogue, la notion principale et le rappel
/// existants sont conservés quand rien n'est donné ; les blocs encore absents
/// sont dérivés de la séance du catalogue (ADR 0007).
@injectable
class OpenOrResumeSession {
  OpenOrResumeSession(
    this._groups,
    this._sessions,
    this._sheetBlocks,
    this._open,
  );

  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final ResolveSheetBlocks _sheetBlocks;
  final OpenSession _open;

  Future<Result<SessionRecord>> call({
    required GroupId groupId,
    required DateTime date,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,
    SheetId? sheetId,
  }) async {
    final existing = recordFor(
      await _sessions.forGroup(groupId),
      date,
      sheetId,
    );
    if (existing == null) {
      return await _open(
        groupId: groupId,
        date: date,
        present: present,
        mainBlockId: mainBlockId,
        recallBlockId: recallBlockId,
        sheetId: sheetId,
      );
    }
    return await runGuarded(() async {
      final group = await _groups.byId(groupId);
      if (group == null) throw NotFound('group', groupId.value);
      if (!present.every((student) => group.isMemberOn(student, date))) {
        throw const InvariantViolation(InvariantCode.studentNotInGroup);
      }
      final sheet = sheetId ?? existing.sheetId;
      final (:main, :recall) = (await _sheetBlocks(sheet)).resolve(
        main: mainBlockId ?? existing.mainBlockId,
        recall: recallBlockId ?? existing.recallBlockId,
      );
      final resumed = existing.copyWith(
        present: present,
        mainBlockId: main,
        recallBlockId: recall,
        sheetId: sheet,
      );
      await _sessions.save(resumed);
      return resumed;
    });
  }
}
