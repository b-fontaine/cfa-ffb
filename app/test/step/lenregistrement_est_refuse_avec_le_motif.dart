import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lenregistrementEstRefuseAvecLeMotif(
  WidgetTester tester,
  String code,
) async {
  final result = TrackingWorld.current.lastRecord;
  expect(result, isA<Err<RecordedAttempt>>());
  final failure = (result as Err<RecordedAttempt>).failure;
  expect(failure, isA<InvariantViolation>());
  expect((failure as InvariantViolation).code.name, code);
}
