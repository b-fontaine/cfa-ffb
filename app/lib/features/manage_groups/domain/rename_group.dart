import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : renommer un groupe. Le nom reste unique dans la saison ; un
/// groupe peut changer la casse de son propre nom.
@injectable
class RenameGroup {
  RenameGroup(this._groups);

  final GroupRepository _groups;

  Future<Result<Group>> call({
    required GroupId groupId,
    required String name,
  }) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final renamed = group.rename(name);
    final wanted = normalizedGroupName(renamed.name);
    final taken = (await _groups.all()).any(
      (other) =>
          other.id != groupId &&
          other.seasonId == group.seasonId &&
          normalizedGroupName(other.name) == wanted,
    );
    if (taken) throw const InvariantViolation(InvariantCode.groupNameTaken);
    await _groups.save(renamed);
    return renamed;
  });
}
