import 'dart:async';

import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firebase_options.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
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
  runApp(const App());
}
