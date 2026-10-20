import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanEstBloquePourLeMotif(
  WidgetTester tester,
  String code,
) async {
  final plan = ImportWorld.current.plan!;
  expect(plan.status, ImportStatus.blocked);
  expect(plan.isRunnable, isFalse);
  expect(
    plan.report.problems.map((problem) => problem.code.name),
    contains(code),
  );
}
