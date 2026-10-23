import 'package:billard_cfa/app/data_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataBackend.resolve', () {
    // Garde de la bascule (2026-10-21) : si le défaut redevient drift, un
    // club écrirait sur l'appareil sans le savoir.
    test('defaults to firestore: no setting, blank or firestore', () {
      expect(DataBackend.resolve(''), DataBackend.firestore);
      expect(DataBackend.resolve('  '), DataBackend.firestore);
      expect(DataBackend.resolve('firestore'), DataBackend.firestore);
      expect(DataBackend.resolve(' Firestore '), DataBackend.firestore);
    });

    test('drift only when asked explicitly, whatever the case', () {
      expect(DataBackend.resolve('drift'), DataBackend.drift);
      expect(DataBackend.resolve(' Drift '), DataBackend.drift);
    });

    test('an unknown value is an error, never a silent fallback', () {
      expect(
        () => DataBackend.resolve('firebase'),
        throwsA(
          isA<DataBackendError>().having(
            (e) => e.toString(),
            'message',
            contains('"firebase"'),
          ),
        ),
      );
    });
  });

  test('the build of the test suite sets nothing: firestore', () {
    expect(DataBackend.fromBuild(), DataBackend.firestore);
  });

  group('choose', () {
    test('builds only the chosen implementation', () {
      final built = <String>[];
      String make(String name) {
        built.add(name);
        return name;
      }

      final first = DataBackend.drift.choose(
        drift: () => make('drift'),
        firestore: () => make('firestore'),
      );
      final second = DataBackend.firestore.choose(
        drift: () => make('drift2'),
        firestore: () => make('firestore2'),
      );

      expect(built, ['drift', 'firestore2']);
      expect([first, second], ['drift', 'firestore2']);
    });
  });
}
