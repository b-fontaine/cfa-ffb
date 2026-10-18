import 'package:billard_cfa/app/data_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataBackend.resolve', () {
    test('defaults to drift: no setting, empty or drift', () {
      expect(DataBackend.resolve(''), DataBackend.drift);
      expect(DataBackend.resolve('  '), DataBackend.drift);
      expect(DataBackend.resolve('drift'), DataBackend.drift);
    });

    test('firestore only when asked, whatever the case', () {
      expect(DataBackend.resolve('firestore'), DataBackend.firestore);
      expect(DataBackend.resolve(' Firestore '), DataBackend.firestore);
    });

    test('an unknown value is an error, never a silent drift', () {
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

  test('the build of the test suite sets nothing: drift', () {
    expect(DataBackend.fromBuild(), DataBackend.drift);
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
