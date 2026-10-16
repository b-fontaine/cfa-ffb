import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Usage: I go to the address of the grid of the group {'Children group'}
Future<void> iGoToTheAddressOfTheGridOfTheGroup(
  WidgetTester tester,
  String name,
) async {
  final groups = await tester.runAsync(() => getIt<GroupRepository>().all());
  final group = groups!.firstWhere((g) => g.name == name);
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go('/students/groups/${group.id.value}');
  await tester.pumpAndSettle();
}
