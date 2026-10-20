import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> lePlafondDecrituresParJourEstDe(
  WidgetTester tester,
  num writes,
) async {
  // Des lots de la moitié du plafond : le plan en compte plusieurs.
  ImportWorld.current.limits = ImportLimits(
    lotSize: writes.toInt() ~/ 2,
    dailyWrites: writes.toInt(),
  );
}
