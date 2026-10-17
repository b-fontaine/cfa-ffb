import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/platform/firebase_sdk_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialize delegates to the SDK entry point', () async {
    final calls = <String>[];
    final FirebaseGateway gateway = FirebaseSdkGateway(
      initializeApp: (options) async =>
          calls.add('initializeApp ${options.projectId}'),
      useAuthEmulator: (host, port) async => calls.add('auth $host:$port'),
      useFirestoreEmulator: (host, port) => calls.add('firestore $host:$port'),
    );

    await gateway.initialize(emulator: false);

    expect(calls, ['initializeApp animation-billard']);
  });

  test('against the emulators, the app takes the emulator project', () async {
    final projects = <String>[];
    final FirebaseGateway gateway = FirebaseSdkGateway(
      initializeApp: (options) async => projects.add(options.projectId),
      useAuthEmulator: (host, port) async {},
      useFirestoreEmulator: (host, port) {},
    );

    await gateway.initialize(emulator: true);

    // Les émulateurs sont lancés sur ce projet « demo-… » (Taskfile,
    // scripts/rules_test.sh) et la graine le refuse autrement : un autre
    // identifiant ferait lire à l'application une base vide.
    expect(projects, [FirebaseEnvironment.emulatorProjectId]);
    expect(FirebaseEnvironment.emulatorProjectId, startsWith('demo-'));
  });

  test('useEmulators points Auth and Firestore at their ports', () async {
    final calls = <String>[];
    await FirebaseSdkGateway(
      initializeApp: (options) async {},
      useAuthEmulator: (host, port) async => calls.add('auth $host:$port'),
      useFirestoreEmulator: (host, port) => calls.add('firestore $host:$port'),
    ).useEmulators(host: '10.0.2.2', authPort: 9099, firestorePort: 8080);

    expect(calls, ['auth 10.0.2.2:9099', 'firestore 10.0.2.2:8080']);
  });

  test('builds with the real SDK by default, without calling it', () {
    expect(FirebaseSdkGateway.new, returnsNormally);
  });
}
