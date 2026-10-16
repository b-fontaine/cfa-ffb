import 'package:billard_cfa/app/firebase_startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports a successful initialization', () async {
    var calls = 0;

    final started = await startFirebase(() async => calls++);

    expect(started, isTrue);
    expect(calls, 1);
  });

  test('absorbs an asynchronous failure and reports it', () async {
    final errors = <Object>[];

    final started = await startFirebase(
      () async => throw StateError('SDK injoignable'),
      onError: errors.add,
    );

    expect(started, isFalse);
    expect(errors.single, isA<StateError>());
  });

  test('absorbs a synchronous failure of the options lookup', () async {
    final errors = <Object>[];

    final started = await startFirebase(
      () => throw UnsupportedError('plate-forme sans options'),
      onError: errors.add,
    );

    expect(started, isFalse);
    expect(errors.single, isA<UnsupportedError>());
  });

  test('logs the failure by default instead of throwing', () async {
    final logs = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = original);

    final started = await startFirebase(
      () async => throw Exception('hors ligne'),
    );

    expect(started, isFalse);
    expect(
      logs.single,
      allOf(contains('Firebase indisponible'), contains('hors ligne')),
    );
  });
}
