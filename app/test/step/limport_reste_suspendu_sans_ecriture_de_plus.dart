import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> limportResteSuspenduSansEcritureDePlus(WidgetTester tester) async {
  final world = ImportWorld.current;
  final run = world.run!;
  expect(run.status, ImportRunStatus.paused);
  expect(run.writes, 0);
  expect(run.doneLots, world.marker()!['done']);
  expect(run.doneLots, lessThan(run.totalLots));
}
