import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : supprimer un groupe, seulement s'il est vide, sans séance
/// saisie ni séance planifiée.
///
/// Vide = aucun élève membre au jour donné (`today`) ni plus tard
/// (`groupNotEmpty`). Un
/// groupe qui a donné une séance reste (`groupHasRecords`) : la séance et son
/// historique y sont rattachés. Un groupe visé par une séance planifiée reste
/// aussi (`groupHasPlanned`). Suppression logique : aucune donnée
/// personnelle ne s'y attache.
@injectable
class DeleteGroup {
  DeleteGroup(this._groups, this._sessions, this._planned);

  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final SessionRepository _planned;

  Future<Result<void>> call({
    required GroupId groupId,
    required DateTime today,
  }) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final day = today.dateOnly;
    final occupied = group.memberships.any(
      (m) => m.to == null || !m.to!.dateOnly.isBefore(day),
    );
    if (occupied) throw const InvariantViolation(InvariantCode.groupNotEmpty);
    if ((await _sessions.forGroup(groupId)).isNotEmpty) {
      throw const InvariantViolation(InvariantCode.groupHasRecords);
    }
    // Une séance planifiée qui vise un groupe supprimé ne se réimporterait
    // plus : la sauvegarde exportée serait incohérente.
    if ((await _planned.getAll()).any((s) => s.groupId == groupId)) {
      throw const InvariantViolation(InvariantCode.groupHasPlanned);
    }
    await _groups.delete(groupId);
  });
}
