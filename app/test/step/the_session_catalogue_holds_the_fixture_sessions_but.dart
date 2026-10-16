import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_sheet_fixtures.dart';
import '../support/ui_world.dart';

/// Usage: the session catalogue holds the fixture sessions but {'posture-1'}
///
/// Le catalogue de test privé d'une séance : la notion qu'elle portait (ici le
/// bloc de tête de `posture-1`) n'a plus aucune séance du catalogue.
Future<void> theSessionCatalogueHoldsTheFixtureSessionsBut(
  WidgetTester tester,
  String id,
) async {
  await UiWorld.prepare(tester);
  await getIt.unregister<SessionSheetRepository>();
  getIt.registerSingleton<SessionSheetRepository>(
    FixtureSessionSheetRepository([
      for (final sheet in catalogueFixture())
        if (sheet.id.value != id) sheet,
    ]),
  );
}
