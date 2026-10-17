import 'package:billard_cfa/app/firebase_environment.dart';
import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firebase_gateway.dart';

void main() {
  const production = FirebaseEnvironment.production();
  const emulator = FirebaseEnvironment.emulator(emulatorHost: '10.0.2.2');

  FirebaseStartup startup(
    FakeFirebaseGateway gateway, {
    FirebaseEnvironment environment = production,
    void Function(Object error)? onError,
  }) => FirebaseStartup(
    environment: environment,
    gateway: gateway,
    onError: onError,
  );

  test('initializes Firebase once and reports success', () async {
    final gateway = FakeFirebaseGateway();

    final ready = await (startup(gateway)..start()).ready;

    expect(ready, isTrue);
    expect(gateway.calls, ['initialize']);
    expect(gateway.emulatorRequests, [false]);
  });

  test('never touches the emulators in production', () async {
    final gateway = FakeFirebaseGateway();

    await (startup(gateway)..start()).ready;

    expect(gateway.calls, isNot(contains(startsWith('useEmulators'))));
  });

  test('points Auth and Firestore at the emulator, after initialize', () async {
    final gateway = FakeFirebaseGateway();

    final ready = await (startup(
      gateway,
      environment: emulator,
    )..start()).ready;

    expect(ready, isTrue);
    expect(gateway.calls, ['initialize', 'useEmulators 10.0.2.2 9099 8080']);
    expect(gateway.emulatorRequests, [
      true,
    ], reason: "le projet de l'émulateur est demandé dès l'initialisation");
  });

  test(
    'start is idempotent: one initialization however often it is called',
    () async {
      final gateway = FakeFirebaseGateway();
      final subject = startup(gateway)
        ..start()
        ..start();

      await subject.ready;
      await subject.ready;

      expect(gateway.calls, ['initialize']);
    },
  );

  test('ready starts the initialization when nobody did', () async {
    final gateway = FakeFirebaseGateway();

    expect(await startup(gateway).ready, isTrue);
    expect(gateway.calls, ['initialize']);
  });

  test('exposes the outcome once resolved', () async {
    final subject = startup(FakeFirebaseGateway());
    expect(subject.isReady, isNull);

    await (subject..start()).ready;

    expect(subject.isReady, isTrue);
  });

  test('absorbs an asynchronous failure and reports it', () async {
    final errors = <Object>[];
    final gateway = FakeFirebaseGateway(
      initializeError: StateError('SDK injoignable'),
    );

    final subject = startup(gateway, onError: errors.add)..start();

    expect(await subject.ready, isFalse);
    expect(subject.isReady, isFalse);
    expect(errors.single, isA<StateError>());
  });

  test('absorbs a synchronous failure of the options lookup', () async {
    final errors = <Object>[];
    final gateway = FakeFirebaseGateway(
      initializeThrowsSynchronously: UnsupportedError(
        'plate-forme sans options',
      ),
    );

    final subject = startup(gateway, onError: errors.add)..start();

    expect(await subject.ready, isFalse);
    expect(errors.single, isA<UnsupportedError>());
  });

  test('a failed emulator configuration is a failed start', () async {
    final errors = <Object>[];
    final gateway = FakeFirebaseGateway(
      useEmulatorsError: StateError('déjà utilisé'),
    );

    final subject = startup(gateway, environment: emulator, onError: errors.add)
      ..start();

    expect(await subject.ready, isFalse);
    expect(errors.single, isA<StateError>());
  });

  test('a failure is memoized, not retried', () async {
    final gateway = FakeFirebaseGateway(
      initializeError: StateError('hors ligne'),
    );
    final subject = startup(gateway, onError: (_) {})..start();

    await subject.ready;
    subject.start();
    await subject.ready;

    expect(gateway.calls, ['initialize']);
  });

  test('logs the failure by default instead of throwing', () async {
    final logs = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = original);
    final gateway = FakeFirebaseGateway(
      initializeError: Exception('hors ligne'),
    );

    final ready = await (startup(gateway)..start()).ready;

    expect(ready, isFalse);
    expect(
      logs.single,
      allOf(contains('Firebase indisponible'), contains('hors ligne')),
    );
  });

  group('retry', () {
    test('runs the initialization again after a failure', () async {
      final gateway = FakeFirebaseGateway(initializeError: StateError('down'));
      final subject = startup(gateway, onError: (_) {});
      expect(await subject.ready, isFalse);

      gateway.initializeError = null;
      final ready = await subject.retry();

      expect(ready, isTrue);
      expect(subject.isReady, isTrue);
      expect(gateway.calls, ['initialize', 'initialize']);
    });

    test('does nothing after a success', () async {
      final gateway = FakeFirebaseGateway();
      final subject = startup(gateway);
      await subject.ready;

      expect(await subject.retry(), isTrue);
      expect(gateway.calls, ['initialize']);
    });

    test('still reports unavailable while the service is down', () async {
      final gateway = FakeFirebaseGateway(initializeError: StateError('down'));
      final subject = startup(gateway, onError: (_) {});
      await subject.ready;

      expect(await subject.retry(), isFalse);
      expect(gateway.calls, ['initialize', 'initialize']);
    });
  });
}
