import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/ui_world.dart';

/// Usage: I open the summary of the session of the group {'Children group'} on
/// {'2026-10-12'}
///
/// Démarre l'application, puis ouvre par son adresse le bilan de la saisie du
/// groupe à cette date (lien profond, relu depuis la persistance).
Future<void> iOpenTheSummaryOfTheSessionOfTheGroupOn(
  WidgetTester tester,
  String groupName,
  String date,
) async {
  await UiWorld.prepare(tester);
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == groupName);
  final day = DateTime.parse(date);
  final records = await tester.runAsync(
    () => getIt<SessionRecordRepository>().forGroup(group.id),
  );
  final record = records!.firstWhere(
    (candidate) =>
        candidate.date.year == day.year &&
        candidate.date.month == day.month &&
        candidate.date.day == day.day,
  );
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go('/record/${record.id.value}/review');
  await tester.pumpAndSettle();
}
