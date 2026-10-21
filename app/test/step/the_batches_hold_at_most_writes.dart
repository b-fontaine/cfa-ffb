import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the batches hold at most {60} writes
Future<void> theBatchesHoldAtMostWrites(WidgetTester tester, num writes) async {
  ImportWorld.current.limits = ImportLimits(lotSize: writes.toInt());
}
