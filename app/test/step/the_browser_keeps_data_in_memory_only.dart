import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/shared/lib/storage_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the browser keeps data in memory only
Future<void> theBrowserKeepsDataInMemoryOnly(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  (getIt<StorageStatus>() as InMemoryStorageStatus)
    ..implementation = StorageImplementation.inMemory
    ..degradationReasons = const ['OPFS unavailable'];
}
