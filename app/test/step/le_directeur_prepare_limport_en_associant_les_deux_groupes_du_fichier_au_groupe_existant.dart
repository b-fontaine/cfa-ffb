import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void>
leDirecteurPrepareLimportEnAssociantLesDeuxGroupesDuFichierAuGroupeExistant(
  WidgetTester tester,
  String name,
) async {
  final world = ImportWorld.current..act(Role.director);
  final target = GroupId('g-${name.toLowerCase()}');
  world.decisions = world.decisions.copyWith(
    groups: {
      world.backup!.groupId(1): UseExistingGroup(target),
      world.backup!.groupId(2): UseExistingGroup(target),
    },
  );
  await world.prepare();
}
