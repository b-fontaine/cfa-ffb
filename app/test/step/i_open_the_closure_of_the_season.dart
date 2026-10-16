import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Usage: I open the closure of the season {'2026-2027'}
Future<void> iOpenTheClosureOfTheSeason(
  WidgetTester tester,
  String label,
) async {
  final seasons = await tester.runAsync(() => getIt<SeasonRepository>().all());
  final season = seasons!.firstWhere((s) => s.label == label);
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go('/seasons/${season.id.value}/close');
  await tester.pumpAndSettle();
}
