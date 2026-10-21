import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage: I attach the session {'p-orphan'} to {'Skip (do not import)'}
Future<void> iAttachTheSessionTo(
  WidgetTester tester,
  String id,
  String option,
) async {
  await ImportScreenWorld.choose(
    tester,
    find.byKey(ValueKey('import-session-$id')),
    option,
  );
}
