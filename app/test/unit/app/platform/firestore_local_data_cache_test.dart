import 'dart:async';

import 'package:billard_cfa/app/platform/firestore_local_data_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clearing terminates the instance, then drops its storage', () async {
    final calls = <String>[];
    final cache = FirestoreLocalDataCache(
      reload: () async => calls.add('reload'),
      terminate: () async => calls.add('terminate'),
      clearPersistence: () async => calls.add('clearPersistence'),
    );

    await cache.clear();

    // `clearPersistence` échoue sur une instance démarrée : l'ordre compte, et
    // la page n'est PAS rechargée par l'effacement lui-même.
    expect(calls, ['terminate', 'clearPersistence']);
  });

  test(
    'a storage that cannot be dropped raises: nothing is claimed cleared',
    () async {
      final cache = FirestoreLocalDataCache(
        reload: () async {},
        terminate: () async {},
        clearPersistence: () => throw const FormatException('autre onglet'),
      );

      await expectLater(cache.clear(), throwsFormatException);
    },
  );

  test('reopening reloads the page', () async {
    var reloads = 0;
    final cache = FirestoreLocalDataCache(
      reload: () async => reloads++,
      terminate: () async {},
      clearPersistence: () async {},
      native: false,
    );

    await cache.reopen();

    expect(reloads, 1);
  });

  test('builds with the real SDK by default, without calling it', () {
    expect(() => FirestoreLocalDataCache(reload: () async {}), returnsNormally);
  });

  test('a storage held open by another tab does not block for ever: the '
      'clearing fails once the delay is over', () async {
    final cache = FirestoreLocalDataCache(
      reload: () async {},
      terminate: () async {},
      clearPersistence: () => Completer<void>().future,
      clearTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(cache.clear(), throwsA(isA<TimeoutException>()));
  });

  test('natively, reopening re-applies the settings, then reloads', () async {
    final calls = <String>[];
    final cache = FirestoreLocalDataCache(
      reload: () async => calls.add('reload'),
      terminate: () async {},
      clearPersistence: () async {},
      reapplySettings: () => calls.add('settings'),
      native: true,
    );

    await cache.reopen();

    expect(calls, ['settings', 'reload']);
  });

  test('on the web, reopening only reloads the page', () async {
    final calls = <String>[];
    final cache = FirestoreLocalDataCache(
      reload: () async => calls.add('reload'),
      terminate: () async {},
      clearPersistence: () async {},
      reapplySettings: () => calls.add('settings'),
      native: false,
    );

    await cache.reopen();

    expect(calls, ['reload']);
  });
}
