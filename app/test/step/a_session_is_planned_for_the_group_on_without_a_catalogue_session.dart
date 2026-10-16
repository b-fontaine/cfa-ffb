import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a session {'Cours'} is planned for the group {'Children group'} on
/// {'2026-10-14'} without a catalogue session
///
/// Planifie par le cas d'usage réel une séance libre (sans séance du
/// catalogue) pour le groupe du nom donné.
Future<void> aSessionIsPlannedForTheGroupOnWithoutACatalogueSession(
  WidgetTester tester,
  String title,
  String groupName,
  String date,
) async {
  await UiWorld.prepare(tester);
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  await tester.runAsync(
    () => getIt<PlanSession>()(
      title: title,
      date: DateTime.parse(date),
      audience: group.audience,
      groupId: group.id,
    ),
  );
}
