import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leMarqueurDimportDuDirecteurEstLeSien(WidgetTester tester) async {
  final world = ImportWorld.current;
  final fingerprint = sha256Hex(world.content!);
  final mine = world.server.read('clubs/c1/imports/${fingerprint}_u-import');
  expect(mine, isNotNull);
  expect(mine!['createdBy'], 'u-import');
  expect(mine['state'], ImportState.done.name);
  expect(mine['planId'], world.plan!.planId);
  // Celui de l'autre compte est resté tel quel.
  expect(
    world.server.read('clubs/c1/imports/${fingerprint}_u-teacher')!['planId'],
    'd' * 64,
  );
}
