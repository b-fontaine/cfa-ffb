import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurRattacheCetteSeanceAuPremierGroupeDuFichier(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  world.decisions = world.decisions.copyWith(
    plannedSessions: {'p-orphan': AttachTo(world.backup!.groupId(1))},
  );
  await world.prepare();
}
