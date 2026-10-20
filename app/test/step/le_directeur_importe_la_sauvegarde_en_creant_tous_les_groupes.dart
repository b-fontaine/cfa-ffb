import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurImporteLaSauvegardeEnCreantTousLesGroupes(
  WidgetTester tester,
) async {
  final world = ImportWorld.current..act(Role.director);
  world.decisions = world.createAll();
  final plan = await world.prepare();
  expect(plan.status, ImportStatus.ready, reason: '${plan.report.problems}');
  final run = await world.runPlan();
  expect(run.status, ImportRunStatus.completed);
}
