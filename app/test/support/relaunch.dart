import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// L'adresse affichée par le routeur de l'application ouverte.
String currentAddress(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .routeInformationProvider
        .value
        .uri
        .toString();

/// Ferme l'application puis la rouvre, comme un rechargement de la page web ou
/// un nouveau lancement : les écrans et la mémoire des séances guidées sont
/// perdus, **les données de l'appareil restent** (dépôts), et le démarrage
/// remet en place les séances guidées en cours (`main()`).
///
/// [address] : l'adresse à rouvrir (ce que la barre d'adresse du navigateur
/// garde), `null` pour l'accueil.
Future<void> relaunchApp(WidgetTester tester, {String? address}) async {
  await tester.pumpWidget(const SizedBox());
  // Ni l'un ni l'autre sous `runAsync` : les cubits restaurés doivent naître
  // dans la zone du test (leur fermeture y attend ses flux), et tout ce que le
  // déroulé lit est déjà en cache (`UiWorld.prepare`).
  await getIt<RunSheetSessions>().dispose();
  await getIt<RunSheetSessions>().restore();
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  if (address != null && address != '/') {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(address);
    await tester.pumpAndSettle();
  }
}
