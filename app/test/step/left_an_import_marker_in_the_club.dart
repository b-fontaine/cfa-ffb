import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'coach@example.org'} left an import marker in the club
/// {'Test club'}
///
/// Un marqueur d'import terminé de ce compte
/// (`clubs/{c}/imports/{empreinte}_{uid}`), comme après une migration.
Future<void> leftAnImportMarkerInTheClub(
  WidgetTester tester,
  String email,
  String club,
) async {
  await UiWorld.prepare(tester);
  final account = UiWorld.auth.accountOf(email)!;
  final fileId = 'a' * 64;
  final path = ClubPaths(UiWorld.clubIdOf(club))
      .importMarker(fileId, account.id);
  UiWorld.documents.seed(path, {
    'fileId': fileId,
    'planId': 'b' * 64,
    'lots': 1,
    'done': 1,
    'writes': 12,
    'restored': 0,
    'role': 'teacher',
    'createdBy': account.id.value,
    'state': 'done',
    'startedAt': UiWorld.today,
    'updatedAt': UiWorld.today,
  });
}
