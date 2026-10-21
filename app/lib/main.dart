import 'dart:async';

import 'package:billard_cfa/app/app.dart';
import 'package:billard_cfa/app/data_backend.dart';
import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_sheet_sessions.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:billard_cfa/shared/persistence/local_store_probe.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Build Firestore (FB7c) : relever la base locale AVANT que l'application ne
  // l'ouvre (elle crée une base absente et migre une base ancienne). Sous
  // drift (explicite), la base locale est la source de vérité : rien à relever.
  const settings = DatabaseSettings();
  final localData = DataBackend.fromBuild() == DataBackend.firestore
      ? await probeLocalStore(settings)
      : LocalDataInventory.none;
  await configureDependencies(localData: localData);
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
