import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

Future<void> lenseignantPrepareLimportDeSonSeulGroupe(
  WidgetTester tester,
) async {
  // Un seul groupe dans le fichier : l'enseignant n'a qu'un groupe.
  final single = RealisticBackup(groups: 1);
  final world = ImportWorld.current
    ..backup = single
    ..content = single.content;
  world.act(Role.teacher, groups: world.teacherGroups.toList());
  world.decisions = world.decisions.copyWith(
    groups: {
      for (final group in world.backup!.snapshot.groups)
        group.id: UseExistingGroup(GroupId(world.teacherGroups.first)),
    },
  );
  await world.prepare();
}
