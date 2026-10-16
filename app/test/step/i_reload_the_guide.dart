import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Usage: I reload the guide
///
/// Recharger la page : les séances guidées en mémoire sont perdues et le guide
/// est rouvert à la seule adresse courante (ce que la barre d'adresse du
/// navigateur garde). Simulation : le `GoRouter` lui-même n'est pas
/// reconstruit ; le step prouve que l'adresse seule porte le mode.
Future<void> iReloadTheGuide(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  final router = GoRouter.of(context);
  final address = router.routeInformationProvider.value.uri.toString();
  // Un rechargement reconstruit tout : on quitte d'abord la page (elle ne doit
  // plus tenir un cubit fermé), puis on perd les séances en mémoire.
  router.go('/');
  await tester.pumpAndSettle();
  await tester.runAsync(getIt<RunSheetSessions>().dispose);
  router.go(address);
  await tester.pumpAndSettle();
}
