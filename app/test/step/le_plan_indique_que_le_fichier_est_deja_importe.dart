import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlanIndiqueQueLeFichierEstDejaImporte(
  WidgetTester tester,
) async {
  expect(ImportWorld.current.plan!.status, ImportStatus.alreadyImported);
  expect(ImportWorld.current.plan!.isRunnable, isFalse);
}
