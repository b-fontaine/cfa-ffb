import 'package:billard_cfa/app/firebase_gateway.dart';
import 'package:billard_cfa/app/platform/firebase_sdk_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialize delegates to the SDK entry point', () async {
    final calls = <String>[];
    final FirebaseGateway gateway = FirebaseSdkGateway(
      initializeApp: () async => calls.add('initializeApp'),
      useAuthEmulator: (host, port) async => calls.add('auth $host:$port'),
      useFirestoreEmulator: (host, port) => calls.add('firestore $host:$port'),
    );

    await gateway.initialize();

    expect(calls, ['initializeApp']);
  });

  test('useEmulators points Auth and Firestore at their ports', () async {
    final calls = <String>[];
    await FirebaseSdkGateway(
      initializeApp: () async {},
      useAuthEmulator: (host, port) async => calls.add('auth $host:$port'),
      useFirestoreEmulator: (host, port) => calls.add('firestore $host:$port'),
    ).useEmulators(host: '10.0.2.2', authPort: 9099, firestorePort: 8080);

    expect(calls, ['auth 10.0.2.2:9099', 'firestore 10.0.2.2:8080']);
  });

  test('builds with the real SDK by default, without calling it', () {
    expect(FirebaseSdkGateway.new, returnsNormally);
  });
}
