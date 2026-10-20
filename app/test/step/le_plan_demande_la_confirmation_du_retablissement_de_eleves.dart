import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanDemandeLaConfirmationDuRetablissementDeEleves(
  WidgetTester tester,
  num students,
) async {
  final plan = ImportWorld.current.plan!;
  expect(plan.status, ImportStatus.needsConfirmation);
  expect(plan.report.restoredStudents, students.toInt());
  expect(plan.isRunnable, isFalse);
}
