import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève est refusée car l'élève est introuvable
Future<void> laVueEleveEstRefuseeCarLeleveEstIntrouvable(
  WidgetTester tester,
) async {
  expect(
    TrackingWorld.current.showcaseResult,
    isA<Err<Object?>>().having(
      (r) => r.failure,
      'failure',
      isA<NotFound>().having((f) => f.kind, 'kind', 'student'),
    ),
  );
}
