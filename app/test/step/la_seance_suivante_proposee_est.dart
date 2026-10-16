import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance suivante proposée est {'posture-2'}
Future<void> laSeanceSuivanteProposeeEst(
  WidgetTester tester,
  String sheet,
) async {
  expect(TrackingWorld.current.nextSheet.sheet?.option.id, SheetId(sheet));
}
