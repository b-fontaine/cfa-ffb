import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:flutter/foundation.dart';

/// Initialisation de Firebase, point d'entrée testable du lot FB1.
///
/// Elle n'empêche jamais l'application de démarrer (lot 15) : hors ligne, le
/// SDK web (chargé depuis le CDN de Google) est injoignable et l'application
/// doit quand même s'ouvrir avec ses données locales. [start] lance donc
/// l'initialisation sans bloquer, et le résultat reste **attendable** par
/// qui en dépend : l'`AuthCubit` du lot FB2 fait `await startup.ready`
/// (ADR 0024, B8). Rien n'est perdu en route (pas de `unawaited`) : le futur
/// est conservé, l'échec est signalé et mémorisé, jamais relancé en silence.
class FirebaseStartup implements SessionStartup {
  FirebaseStartup({
    required this.environment,
    required this.gateway,
    void Function(Object error)? onError,
  }) : _onError = onError ?? _logError;

  final FirebaseEnvironment environment;
  final FirebaseGateway gateway;
  final void Function(Object error) _onError;

  Future<bool>? _ready;
  bool? _outcome;

  /// Lance l'initialisation une seule fois (idempotent).
  void start() => _ready ??= _initialize();

  /// Vaut `true` si Firebase est prêt, `false` s'il est indisponible. Ne
  /// lève jamais ; lance l'initialisation si personne ne l'a fait.
  @override
  Future<bool> get ready => _ready ??= _initialize();

  /// Relance l'initialisation **seulement si elle a échoué** (bouton
  /// « Réessayer » de l'écran « indisponible ») ; sans effet si elle a réussi
  /// ou si elle est encore en cours.
  @override
  Future<bool> retry() {
    if (_outcome == false) {
      _ready = null;
      _outcome = null;
    }
    return ready;
  }

  /// `null` tant que l'initialisation n'est pas terminée.
  bool? get isReady => _outcome;

  Future<bool> _initialize() async {
    try {
      await gateway.initialize();
      if (environment.usesEmulator) {
        await gateway.useEmulators(
          host: environment.emulatorHost!,
          authPort: FirebaseEnvironment.authPort,
          firestorePort: FirebaseEnvironment.firestorePort,
        );
      }
      return _outcome = true;
    } on Object catch (error) {
      _onError(error);
      return _outcome = false;
    }
  }

  static void _logError(Object error) =>
      debugPrint('Firebase indisponible : $error');
}
