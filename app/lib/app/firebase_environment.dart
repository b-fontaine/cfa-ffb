import 'package:flutter/foundation.dart';

/// Où parle le SDK Firebase.
enum FirebaseTarget { production, emulator }

/// Un build de production ne doit jamais viser l'émulateur : refus bruyant.
class FirebaseEnvironmentError extends Error {
  FirebaseEnvironmentError(this.message);

  final String message;

  @override
  String toString() => 'FirebaseEnvironmentError: $message';
}

/// Cible de Firebase pour ce build (ADR 0024, lot FB1).
///
/// Valeur sûre par défaut : sans `--dart-define=FIREBASE_EMULATOR=true`, jamais
/// d'émulateur. Avec le drapeau, les builds debug et profile parlent aux
/// émulateurs locaux (ports de `firebase.json`) ; un build **release** qui le
/// demande est refusé ([FirebaseEnvironmentError]).
///
/// `--dart-define=FIREBASE_EMULATOR_HOST=<adresse>` remplace l'hôte par défaut
/// (appareil physique : adresse du poste sur le réseau local).
@immutable
class FirebaseEnvironment {
  const FirebaseEnvironment.production()
    : target = FirebaseTarget.production,
      emulatorHost = null;

  const FirebaseEnvironment.emulator({required String this.emulatorHost})
    : target = FirebaseTarget.emulator;

  /// Lit les `--dart-define` et le mode de compilation du build courant.
  factory FirebaseEnvironment.fromBuild() => FirebaseEnvironment.resolve(
    emulatorRequested: const bool.fromEnvironment('FIREBASE_EMULATOR'),
    releaseMode: kReleaseMode,
    web: kIsWeb,
    platform: defaultTargetPlatform,
    emulatorHost: const String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
  );

  /// Décision pure (testable) : voir la documentation de la classe.
  factory FirebaseEnvironment.resolve({
    required bool emulatorRequested,
    required bool releaseMode,
    required bool web,
    required TargetPlatform platform,
    required String emulatorHost,
  }) {
    if (!emulatorRequested) {
      return const FirebaseEnvironment.production();
    }
    if (releaseMode) {
      throw FirebaseEnvironmentError(
        'FIREBASE_EMULATOR=true est refusé dans un build release : '
        'un build publié ne parle jamais aux émulateurs. '
        'Retirer le drapeau ou construire en debug.',
      );
    }
    if (emulatorHost.isNotEmpty) {
      return FirebaseEnvironment.emulator(emulatorHost: emulatorHost);
    }
    // L'émulateur Android voit le poste hôte à 10.0.2.2 (pas 127.0.0.1).
    final androidEmulator = !web && platform == TargetPlatform.android;
    return FirebaseEnvironment.emulator(
      emulatorHost: androidEmulator ? '10.0.2.2' : '127.0.0.1',
    );
  }

  /// Ports de `emulators` dans `firebase.json` (garde : test dédié).
  static const authPort = 9099;
  static const firestorePort = 8080;

  final FirebaseTarget target;

  /// Adresse des émulateurs, `null` en production.
  final String? emulatorHost;

  bool get usesEmulator => target == FirebaseTarget.emulator;
}
