import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_sheet_fixtures.dart';
import '../support/ui_world.dart';

/// Usage: the session catalogue is empty
Future<void> theSessionCatalogueIsEmpty(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  await getIt.unregister<SessionSheetRepository>();
  getIt.registerSingleton<SessionSheetRepository>(
    FixtureSessionSheetRepository(const []),
  );
}
