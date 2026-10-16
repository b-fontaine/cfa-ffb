import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I pick the group {'Children group'} in the catalogue
Future<void> iPickTheGroupInTheCatalogue(
  WidgetTester tester,
  String name,
) async {
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == name);
  final chip = find.byKey(ValueKey('catalogue-group:${group.id.value}'));
  expect(chip, findsOneWidget, reason: 'groupe $name absent du sélecteur');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
