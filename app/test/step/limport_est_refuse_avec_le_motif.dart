import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> limportEstRefuseAvecLeMotif(
  WidgetTester tester,
  String code,
) async {
  final result = TrackingWorld.current.lastImport;
  expect(result, isA<Err<ImportSummary>>());
  final failure = (result as Err<ImportSummary>).failure;
  expect(failure, isA<InvariantViolation>());
  expect((failure as InvariantViolation).code.name, code);
}
