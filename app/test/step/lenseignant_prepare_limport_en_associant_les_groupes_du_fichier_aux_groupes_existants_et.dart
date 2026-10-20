import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void>
lenseignantPrepareLimportEnAssociantLesGroupesDuFichierAuxGroupesExistantsEt(
  WidgetTester tester,
  String first,
  String second,
) async {
  final world = ImportWorld.current;
  world.act(Role.teacher, groups: world.teacherGroups.toList());
  GroupId id(String name) => GroupId('g-${name.toLowerCase()}');
  world.decisions = world.decisions.copyWith(
    groups: {
      world.backup!.groupId(1): UseExistingGroup(id(first)),
      world.backup!.groupId(2): UseExistingGroup(id(second)),
    },
  );
  await world.prepare();
}
