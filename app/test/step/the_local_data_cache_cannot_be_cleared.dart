import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the local data cache cannot be cleared
///
/// Autre onglet qui tient la base, disque : chaque effacement échoue. L'échec
/// est aussi journalisé (`FlutterError.reportError`), ce que ce scénario
/// attend : il ne doit pas faire échouer le test.
Future<void> theLocalDataCacheCannotBeCleared(WidgetTester tester) async {
  UiWorld.localCache.clearFailure = const FormatException('disque');
  final previous = FlutterError.onError;
  FlutterError.onError = (_) {};
  addTearDown(() => FlutterError.onError = previous);
}
