import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/change_audience/domain/change_audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le passage de {'Hugo'} en public {'enfants'} au {'2040-01-01'} est
///   refusé avec le motif {'audienceHistoryTooLong'}
Future<void> lePassageDeEnPublicAuEstRefuseAvecLeMotif(
  WidgetTester tester,
  String student,
  String audience,
  String date,
  String code,
) async {
  final result = await getIt<ChangeAudience>()(
    studentId: TrackingWorld.studentId(student),
    audience: TrackingWorld.audience(audience),
    effectiveFrom: TrackingWorld.date(date),
  );
  switch (result) {
    case Err(failure: InvariantViolation(code: final actual)):
      expect(actual.name, code);
    default:
      fail('le passage aurait dû être refusé : $result');
  }
}
