import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Usage: the planner address carries the group {'Children group'}
///
/// Lit l'adresse courante du routeur : le planificateur (`/planner`) et son
/// paramètre `group`, identifiant du groupe du nom donné. Prouve que le
/// groupe choisi en amont arrive dans l'adresse du planificateur, donc qu'il
/// y est présélectionné (ADR 0007 amendé : une séance planifiée a un groupe).
Future<void> thePlannerAddressCarriesTheGroup(
  WidgetTester tester,
  String name,
) async {
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((candidate) => candidate.name == name);
  final context = tester.element(find.byType(Scaffold).first);
  final uri = GoRouter.of(context).routeInformationProvider.value.uri;
  expect(uri.path, '/planner');
  expect(uri.queryParameters['group'], group.id.value);
}
