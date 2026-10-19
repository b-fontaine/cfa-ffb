import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Réglage du cache local de Firestore (ADR 0024, décision 1 et C4) : la
/// persistance hors ligne est **activée explicitement** (le web, lui, ne la
/// fournit pas par défaut : cache en mémoire), en mode **multi-onglets** pour
/// que deux onglets ouverts sur l'application partagent le même cache au lieu
/// de s'exclure (`WebPersistentMultipleTabManager` n'agit que sur le web ; le
/// natif a la persistance par défaut). Les données des élèves y restent sur
/// l'appareil jusqu'à la déconnexion (`LocalDataGuard`).
const firestorePersistentCache = Settings(
  persistenceEnabled: true,
  webPersistentTabManager: WebPersistentMultipleTabManager(),
);

/// Passerelle vers le vrai SDK FlutterFire. Les appels sont injectables pour
/// que les tests n'atteignent jamais le SDK ni le réseau.
class FirebaseSdkGateway implements FirebaseGateway {
  FirebaseSdkGateway({
    Future<void> Function(FirebaseOptions options)? initializeApp,
    void Function(Settings settings)? configureFirestore,
    Future<void> Function(String host, int port)? useAuthEmulator,
    void Function(String host, int port)? useFirestoreEmulator,
  }) : _initializeApp = initializeApp ?? _initializeDefaultApp,
       _configureFirestore =
           configureFirestore ??
           ((settings) => FirebaseFirestore.instance.settings = settings),
       _useAuthEmulator = useAuthEmulator ?? _useDefaultAuthEmulator,
       _useFirestoreEmulator =
           useFirestoreEmulator ?? _useDefaultFirestoreEmulator;

  final Future<void> Function(FirebaseOptions options) _initializeApp;
  final void Function(Settings settings) _configureFirestore;
  final Future<void> Function(String host, int port) _useAuthEmulator;
  final void Function(String host, int port) _useFirestoreEmulator;

  /// Initialise l'application, puis règle le cache de Firestore : le réglage
  /// doit précéder tout usage de Firestore, **émulateur compris**
  /// (`useEmulators` vient après ; sur le web, la connexion à l'émulateur crée
  /// l'instance et figerait un cache en mémoire).
  @override
  Future<void> initialize({required bool emulator}) async {
    final options = DefaultFirebaseOptions.currentPlatform;
    await _initializeApp(
      emulator
          ? options.copyWith(projectId: FirebaseEnvironment.emulatorProjectId)
          : options,
    );
    _configureFirestore(firestorePersistentCache);
  }

  @override
  Future<void> useEmulators({
    required String host,
    required int authPort,
    required int firestorePort,
  }) async {
    await _useAuthEmulator(host, authPort);
    _useFirestoreEmulator(host, firestorePort);
  }

  static Future<void> _initializeDefaultApp(FirebaseOptions options) =>
      Firebase.initializeApp(options: options);

  static Future<void> _useDefaultAuthEmulator(String host, int port) =>
      FirebaseAuth.instance.useAuthEmulator(host, port);

  static void _useDefaultFirestoreEmulator(String host, int port) =>
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);
}
