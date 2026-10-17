import 'dart:async';

import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Lance l'initialisation sans la bloquer : hors ligne, le SDK web de
  // Firebase est injoignable et ne doit pas empêcher l'application de s'ouvrir
  // (voir hors-ligne-plan.md). Le résultat reste attendable (`ready`) par
  // l'authentification du lot FB2. Le câblage refuse un build release qui
  // demanderait l'émulateur.
  getIt<FirebaseStartup>().start();
  // Non bloquant non plus : les séances guidées en cours gardées sur
  // l'appareil reviennent dès qu'elles sont relues (l'accueil attend cette fin
  // pour les lister).
  unawaited(getIt<RunSheetSessions>().restore());
  runApp(const App());
}
