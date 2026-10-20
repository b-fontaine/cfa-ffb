import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanAvertitQuilFautFractionnerLimportSurJoursAuMoins(
  WidgetTester tester,
  num days,
) async {
  final plan = ImportWorld.current.plan!;
  expect(plan.daysNeeded, greaterThanOrEqualTo(days.toInt()));
  expect(plan.report.warnings, contains(ImportWarning.largeImport));
}
