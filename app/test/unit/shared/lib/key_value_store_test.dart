import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('reads back what was written, per key', () async {
      final store = InMemoryKeyValueStore();

      await store.write('a', '1');
      await store.write('b', '2');

      expect(await store.read('a'), '1');
      expect(await store.read('b'), '2');
      expect(await store.read('c'), isNull);
    });

    test('overwrites and removes', () async {
      final store = InMemoryKeyValueStore();
      await store.write('a', '1');

      await store.write('a', '3');
      expect(await store.read('a'), '3');
      expect(store.entries, {'a': '3'});

      await store.remove('a');
      expect(await store.read('a'), isNull);
      expect(store.entries, isEmpty);
    });
  });

  group('Role.tryParse', () {
    test('reads every role by its name', () {
      for (final role in Role.values) {
        expect(Role.tryParse(role.name), role);
      }
    });

    test('ignores an unknown or missing value', () {
      expect(Role.tryParse('owner'), isNull);
      expect(Role.tryParse(null), isNull);
    });
  });
}
