import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurReprendLimportLeJourMeme(WidgetTester tester) async {
  final world = ImportWorld.current;
  final plan = await world.prepare();
  expect(plan.status, ImportStatus.resumable);
  await world.runPlan();
}
