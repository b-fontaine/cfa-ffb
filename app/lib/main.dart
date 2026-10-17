import 'dart:async';

import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firebase_options.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Non bloquant : hors ligne, le SDK web de Firebase est injoignable et ne
  // doit pas empêcher l'application de s'ouvrir (voir hors-ligne-plan.md).
  unawaited(
    startFirebase(
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
  await configureDependencies();
  // Non bloquant non plus : les séances guidées en cours gardées sur
  // l'appareil reviennent dès qu'elles sont relues (l'accueil attend cette fin
  // pour les lister).
  unawaited(getIt<RunSheetSessions>().restore());
  runApp(const App());
}
