import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the browser installs a new version of the app
///
/// L'application est ouverte : le service worker finit d'installer une
/// version plus récente.
Future<void> theBrowserInstallsANewVersionOfTheApp(WidgetTester tester) async {
  UiWorld.appUpdate.emit(available: true);
  await tester.pumpAndSettle();
}
