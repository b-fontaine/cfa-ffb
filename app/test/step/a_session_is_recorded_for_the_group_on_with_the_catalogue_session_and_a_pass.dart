import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: a session is recorded for the group {'Children group'} on
/// {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
///
/// Ouvre par les cas d'usage réels la séance du groupe à cette date, tous ses
/// membres présents, en notant la séance du catalogue donnée, puis enregistre
/// un passage réussi du premier membre sur le premier exercice de la séance
/// (une séance « donnée » pour la suggestion, ADR 0009).
Future<void> aSessionIsRecordedForTheGroupOnWithTheCatalogueSessionAndAPass(
  WidgetTester tester,
  String groupName,
  String date,
  String sheetId,
) async {
  await UiWorld.prepare(tester);
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  final day = DateTime.parse(date);
  final present = {
    for (final membership in group.memberships)
      if (group.isMemberOn(membership.studentId, day)) membership.studentId,
  };
  final opened = await tester.runAsync<Result<SessionRecord>>(
    () => getIt<OpenSession>()(
      groupId: group.id,
      date: day,
      present: present,
      sheetId: SheetId(sheetId),
    ),
  );
  expect(opened, isA<Ok<Object?>>(), reason: 'ouverture refusée : $opened');
  final session = (opened! as Ok<SessionRecord>).value;
  final exercise = await tester.runAsync(
    () async =>
        (await getIt<SessionSheetRepository>().getById(SheetId(sheetId)))!
            .exercises
            .first
            .ref,
  );
  final spec = (await tester.runAsync(
    () => getIt<CatalogueRepository>().load(),
  ))!.exercise(exercise!)!;
  final recorded = await tester.runAsync(
    () => getIt<RecordAttempt>()(
      sessionId: session.id,
      studentId: present.first,
      exercise: exercise,
      potted: spec.rate.successes,
      total: spec.rate.attempts,
    ),
  );
  expect(recorded, isA<Ok<Object?>>(), reason: 'passage refusé : $recorded');
}
