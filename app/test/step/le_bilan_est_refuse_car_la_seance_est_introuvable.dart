import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le bilan est refusé car la séance est introuvable
Future<void> leBilanEstRefuseCarLaSeanceEstIntrouvable(
  WidgetTester tester,
) async {
  final result = TrackingWorld.current.reviewResult;
  expect(result, isA<Err<Object?>>());
  expect((result as Err).failure, isA<NotFound>());
}
