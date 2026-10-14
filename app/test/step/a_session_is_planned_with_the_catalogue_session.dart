import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a session {'Old plan'} is planned with the catalogue session {'x-9'}
///
/// Planifie directement dans le dépôt une séance liée à un identifiant qui
/// peut ne pas exister dans le catalogue (séance disparue d'une version).
Future<void> aSessionIsPlannedWithTheCatalogueSession(
  WidgetTester tester,
  String title,
  String sheetId,
) async {
  await UiWorld.prepare(tester);
  await getIt<SessionRepository>().add(
    Session(
      id: 'planned-$title',
      title: title,
      date: UiWorld.today,
      audience: Audience.children,
      sheetId: SheetId(sheetId),
    ),
  );
}
