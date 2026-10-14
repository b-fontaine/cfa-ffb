import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance du catalogue proposée est {'coule-2'}
Future<void> laSeanceDuCatalogueProposeeEst(
  WidgetTester tester,
  String sheet,
) async {
  expect(TrackingWorld.current.plan.sheet?.option.id, SheetId(sheet));
}
