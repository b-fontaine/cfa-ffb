import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a session {'Cours'} is planned for the group {'Adults group'} on
/// {'2026-10-19'} with the catalogue session {'demi-bille-1'}
///
/// Planifie par le cas d'usage réel, pour le groupe du nom donné (public du
/// groupe) à la date donnée.
Future<void> aSessionIsPlannedForTheGroupOnWithTheCatalogueSession(
  WidgetTester tester,
  String title,
  String groupName,
  String date,
  String sheetId,
) async {
  await UiWorld.prepare(tester);
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  await tester.runAsync(
    () => getIt<PlanSession>()(
      title: title,
      date: DateTime.parse(date),
      audience: group.audience,
      sheetId: SheetId(sheetId),
      groupId: group.id,
    ),
  );
}
