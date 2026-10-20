import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> limportEstSuspenduApresLePlafondDuJour(WidgetTester tester) async {
  final run = ImportWorld.current.run!;
  expect(run.status, ImportRunStatus.paused);
  expect(run.doneLots, lessThan(run.totalLots));
  expect(run.doneLots, greaterThan(0));
}
