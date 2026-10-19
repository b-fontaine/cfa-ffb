import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/change_feed.dart';
import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';
import 'package:injectable/injectable.dart';

/// Implémentation en mémoire (tests, BDD).
@LazySingleton(as: GroupRepository, env: [Environment.test])
class InMemoryGroupRepository implements GroupRepository {
  final ObservedMap<GroupId, Group> _groups = ObservedMap();

  @override
  Future<void> save(Group group) async => _groups.journaledPut(group.id, group);

  @override
  Future<Group?> byId(GroupId id) async => _groups[id];

  @override
  Future<List<Group>> all() async => _groups.values.toList();

  @override
  Future<void> delete(GroupId id) async => _groups.journaledRemove(id);

  @override
  Future<Set<GroupId>> idsEverContaining(StudentId studentId) async => {
    for (final group in _groups.values)
      if (group.memberships.any((m) => m.studentId == studentId)) group.id,
  };

  @override
  Future<void> eraseStudent(StudentId studentId) async {
    for (final group in _groups.values.toList()) {
      if (group.memberships.every((m) => m.studentId != studentId)) continue;
      _groups.journaledPut(
        group.id,
        group.copyWith(
          memberships: [
            for (final m in group.memberships)
              if (m.studentId != studentId) m,
          ],
        ),
      );
    }
  }

  @override
  Stream<List<Group>> watchAll() => _groups.watch(all);

  @override
  Stream<Group?> watchById(GroupId id) => _groups.watch(() => byId(id));
}
