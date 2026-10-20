import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurReprendLimportLeLendemain(WidgetTester tester) async {
  final world = ImportWorld.current..clock.advance(const Duration(days: 1));
  final plan = await world.prepare();
  expect(plan.status, ImportStatus.resumable);
  final run = await world.runPlan();
  expect(run.status, ImportRunStatus.completed);
}
