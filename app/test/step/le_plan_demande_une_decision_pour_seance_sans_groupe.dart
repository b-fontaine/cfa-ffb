import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanDemandeUneDecisionPourSeanceSansGroupe(
  WidgetTester tester,
  num sessions,
) async {
  final plan = ImportWorld.current.plan!;
  expect(plan.status, ImportStatus.needsDecisions);
  expect(plan.report.undecidedSessions, hasLength(sessions.toInt()));
  expect(plan.isRunnable, isFalse);
}
