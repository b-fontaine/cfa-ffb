import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the group {'Children group'}
///
/// Ouvre le sélecteur « Groupe » du planificateur puis choisit le groupe du
/// nom donné (les options sont repérées par l'identifiant du groupe).
Future<void> iChooseTheGroup(WidgetTester tester, String name) async {
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == name);
  final field = find.byKey(const ValueKey('planner-group-field'));
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('group-option:${group.id.value}'));
  expect(option, findsOneWidget, reason: 'groupe $name absent du sélecteur');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}
