import 'package:billard_cfa/app/platform/shared_preferences_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('reads back what was written', () async {
    final store = SharedPreferencesKeyValueStore();

    await store.write('active_club.u1', '{"club":"c"}');

    expect(await store.read('active_club.u1'), '{"club":"c"}');
    expect(
      await SharedPreferencesAsync().getString('active_club.u1'),
      '{"club":"c"}',
    );
  });

  test('a key never written reads null', () async {
    expect(await SharedPreferencesKeyValueStore().read('nothing'), isNull);
  });

  test('overwrites and removes a key', () async {
    final store = SharedPreferencesKeyValueStore();
    await store.write('k', '1');

    await store.write('k', '2');
    expect(await store.read('k'), '2');

    await store.remove('k');
    expect(await store.read('k'), isNull);
  });
}
