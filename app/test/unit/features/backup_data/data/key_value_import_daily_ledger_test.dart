import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/features/backup_data/data/key_value_import_daily_ledger.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixed_clock.dart';

void main() {
  late InMemoryKeyValueStore store;
  late FixedClock clock;
  late SessionScope scope;
  late KeyValueImportDailyLedger ledger;

  setUp(() {
    store = InMemoryKeyValueStore();
    clock = FixedClock(DateTime(2026, 10, 12, 9));
    scope = SessionScope()..signIn(const UserId('u1'));
    ledger = KeyValueImportDailyLedger(store, clock, scope);
  });

  test('starts at zero and adds up during the day', () async {
    expect(await ledger.spentToday(), 0);
    await ledger.add(40);
    await ledger.add(2);
    expect(await ledger.spentToday(), 42);
    expect(store.entries, {'import.writes.u1': '2026-10-12:42'});
  });

  test('starts again the next day', () async {
    await ledger.add(42);
    clock.advance(const Duration(days: 1));
    expect(await ledger.spentToday(), 0);
    await ledger.add(5);
    expect(store.entries, {'import.writes.u1': '2026-10-13:5'});
  });

  test('is kept per account and survives a new instance', () async {
    await ledger.add(7);
    final again = KeyValueImportDailyLedger(store, clock, scope);
    expect(await again.spentToday(), 7);
    final other = KeyValueImportDailyLedger(
      store,
      clock,
      SessionScope()..signIn(const UserId('u2')),
    );
    expect(await other.spentToday(), 0);
  });

  test('an unreadable value counts as nothing', () async {
    for (final bad in ['', 'x', '2026-10-12:abc', '2026-10-12:1:2']) {
      await store.write('import.writes.u1', bad);
      expect(await ledger.spentToday(), 0, reason: bad);
    }
  });

  test('without an account nothing is kept', () async {
    final anonymous = KeyValueImportDailyLedger(store, clock, SessionScope());
    await anonymous.add(9);
    expect(await anonymous.spentToday(), 0);
    expect(store.entries, isEmpty);
  });
}
