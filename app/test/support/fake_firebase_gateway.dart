import 'package:billard_cfa/app/firebase_gateway.dart';

/// Passerelle Firebase de test : enregistre les appels, échoue à la demande.
class FakeFirebaseGateway implements FirebaseGateway {
  FakeFirebaseGateway({
    this.initializeError,
    this.initializeThrowsSynchronously,
    this.useEmulatorsError,
  });

  /// Modifiable : un test peut réparer le service entre deux tentatives.
  Object? initializeError;
  final Object? initializeThrowsSynchronously;
  final Object? useEmulatorsError;
  final List<String> calls = [];

  @override
  Future<void> initialize() {
    calls.add('initialize');
    final sync = initializeThrowsSynchronously;
    if (sync != null) {
      // ignore: only_throw_errors, simule une erreur lancée avant tout await
      throw sync;
    }
    final error = initializeError;
    return error == null ? Future.value() : Future.error(error);
  }

  @override
  Future<void> useEmulators({
    required String host,
    required int authPort,
    required int firestorePort,
  }) async {
    calls.add('useEmulators $host $authPort $firestorePort');
    final error = useEmulatorsError;
    if (error != null) {
      // ignore: only_throw_errors, simule une erreur du SDK
      throw error;
    }
  }
}
