import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void>
leDirecteurPrepareLaRepriseEnAssociantLePremierGroupeDuFichierAuGroupeExistant(
  WidgetTester tester,
  String name,
) async {
  final world = ImportWorld.current;
  world.store.failAfterBatches = null;
  // Les autres décisions sont celles du premier passage : seul le premier
  // groupe change de destination.
  world.decisions = world.decisions.copyWith(
    groups: {
      ...world.decisions.groups,
      world.backup!.groupId(1): UseExistingGroup(
        GroupId('g-${name.toLowerCase()}'),
      ),
    },
  );
  await world.prepare();
}
