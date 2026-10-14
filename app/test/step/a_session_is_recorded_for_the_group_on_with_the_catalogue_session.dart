import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a session is recorded for the group {'Children group'} on
/// {'2026-10-05'} with the catalogue session {'puissance-1'}
///
/// Ouvre par le cas d'usage réel la séance du groupe à cette date, tous ses
/// membres présents, en notant la séance du catalogue donnée.
Future<void> aSessionIsRecordedForTheGroupOnWithTheCatalogueSession(
  WidgetTester tester,
  String groupName,
  String date,
  String sheetId,
) async {
  await UiWorld.prepare(tester);
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  final day = DateTime.parse(date);
  final result = await tester.runAsync(
    () => getIt<OpenSession>()(
      groupId: group.id,
      date: day,
      present: {
        for (final membership in group.memberships)
          if (group.isMemberOn(membership.studentId, day)) membership.studentId,
      },
      sheetId: SheetId(sheetId),
    ),
  );
  expect(result, isA<Ok<Object?>>(), reason: 'ouverture refusée : $result');
}
