import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la planification est refusée car la date est hors saison
Future<void> laPlanificationEstRefuseeCarLaDateEstHorsSaison(
  WidgetTester tester,
) async {
  final result = TrackingWorld.current.planResult;
  expect(result, isA<Err<Object?>>());
  final failure = (result as Err).failure;
  expect(failure, isA<InvariantViolation>());
  expect(
    (failure as InvariantViolation).code,
    InvariantCode.seasonOutsidePeriod,
  );
}
