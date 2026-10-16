import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Les groupes sont illisibles : toute lecture échoue.
class _UnreadableGroups implements GroupRepository {
  @override
  Future<List<Group>> all() async => throw const NotFound('group', 'illisible');

  @override
  Future<Group?> byId(GroupId id) async =>
      throw const NotFound('group', 'illisible');

  @override
  Future<void> save(Group group) async {}

  @override
  Future<void> delete(GroupId id) async {}

  @override
  Future<void> eraseStudent(StudentId studentId) async {}
}

/// Usage: the groups cannot be read
Future<void> theGroupsCannotBeRead(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await getIt.unregister<GroupRepository>();
  getIt.registerSingleton<GroupRepository>(_UnreadableGroups());
}
