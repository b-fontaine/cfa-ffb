import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanEstPret(WidgetTester tester) async {
  final plan = ImportWorld.current.plan!;
  expect(plan.status, ImportStatus.ready, reason: '${plan.report.problems}');
  expect(plan.isRunnable, isTrue);
}
