import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the browser leaves the full screen
///
/// Échap dans le navigateur : la bascule ne vient pas de l'application.
Future<void> theBrowserLeavesTheFullScreen(WidgetTester tester) async {
  UiWorld.fullscreen.emit(active: false);
  await tester.pumpAndSettle();
}
