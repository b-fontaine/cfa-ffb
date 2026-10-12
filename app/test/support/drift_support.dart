import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Base SQLite en mémoire (vrai moteur SQLite, aucun fichier).
///
/// Chaque appel ouvre son propre exécuteur : plusieurs bases peuvent coexister
/// dans un test (source et cible d'une sauvegarde) sans risque de course, donc
/// l'avertissement « base ouverte plusieurs fois » de drift est désactivé.
AppDatabase openMemoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Horloge qui avance d'une minute à chaque lecture : les horodatages sont
/// déterministes et strictement croissants.
class TickingClock implements Clock {
  TickingClock([DateTime? start]) : _current = start ?? DateTime.utc(2026, 10);

  DateTime _current;

  @override
  DateTime now() {
    final value = _current;
    _current = _current.add(const Duration(minutes: 1));
    return value;
  }
}
