import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la grille est refusée car le groupe est introuvable
Future<void> laGrilleEstRefuseeCarLeGroupeEstIntrouvable(
  WidgetTester tester,
) async {
  expect(
    TrackingWorld.current.gridResult,
    isA<Err<Object?>>().having(
      (r) => r.failure,
      'failure',
      isA<NotFound>().having((f) => f.kind, 'kind', 'group'),
    ),
  );
}
