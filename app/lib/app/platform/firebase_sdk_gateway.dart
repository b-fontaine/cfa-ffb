import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Passerelle vers le vrai SDK FlutterFire. Les trois appels sont injectables
/// pour que les tests n'atteignent jamais le SDK ni le réseau.
class FirebaseSdkGateway implements FirebaseGateway {
  FirebaseSdkGateway({
    Future<void> Function(FirebaseOptions options)? initializeApp,
    Future<void> Function(String host, int port)? useAuthEmulator,
    void Function(String host, int port)? useFirestoreEmulator,
  }) : _initializeApp = initializeApp ?? _initializeDefaultApp,
       _useAuthEmulator = useAuthEmulator ?? _useDefaultAuthEmulator,
       _useFirestoreEmulator =
           useFirestoreEmulator ?? _useDefaultFirestoreEmulator;

  final Future<void> Function(FirebaseOptions options) _initializeApp;
  final Future<void> Function(String host, int port) _useAuthEmulator;
  final void Function(String host, int port) _useFirestoreEmulator;

  @override
  Future<void> initialize({required bool emulator}) {
    final options = DefaultFirebaseOptions.currentPlatform;
    return _initializeApp(
      emulator
          ? options.copyWith(projectId: FirebaseEnvironment.emulatorProjectId)
          : options,
    );
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
