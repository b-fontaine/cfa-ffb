import 'package:billard_cfa/features/backup_data/data/in_memory_local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/domain/local_data_probe.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_data_notice_cubit.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/local_data_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_send_status.dart';

class _ThrowingProbe implements LocalDataProbe {
  @override
  Future<LocalDataInventory> inspect() async => throw StateError('illisible');
}

const _withData = LocalDataInventory(
  state: LocalStoreState.present,
  schemaVersion: 12,
  counts: LocalDataCounts(students: 6, attempts: 72),
);

void main() {
  late InMemoryLocalDataProbe probe;
  late InMemoryKeyValueStore store;
  late FakeSendStatus sends;

  setUp(() {
    probe = InMemoryLocalDataProbe();
    store = InMemoryKeyValueStore();
    sends = FakeSendStatus();
  });

  LocalDataNoticeCubit cubit0() => LocalDataNoticeCubit(probe, store, sends);

  test('nothing to protect: no reminder and no entry', () async {
    final cubit = cubit0();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.visible, isFalse);
    expect(cubit.state.entryVisible, isFalse);
  });

  test('a base with only seasons is not worth a reminder', () async {
    probe.inventory = const LocalDataInventory(
      state: LocalStoreState.present,
      counts: LocalDataCounts(seasons: 1),
    );
    final cubit = cubit0();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.visible, isFalse);
  });

  test('local data show the reminder and the entry', () async {
    probe.inventory = _withData;
    final cubit = cubit0();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.visible, isTrue);
    expect(cubit.state.entryVisible, isTrue);
  });

  test(
    'the reminder goes only on the explicit action, the entry stays',
    () async {
      probe.inventory = _withData;
      final cubit = cubit0();
      addTearDown(cubit.close);
      await cubit.load(account: 'u-anne');

      expect(await cubit.acknowledge(), isTrue);

      expect(cubit.state.visible, isFalse);
      expect(cubit.state.entryVisible, isTrue);
    },
  );

  test(
    'the acknowledgement is kept on the device, with no personal data',
    () async {
      probe.inventory = _withData;
      final first = cubit0();
      await first.load(account: 'u-anne');
      await first.acknowledge();
      await first.close();

      final second = cubit0();
      addTearDown(second.close);
      await second.load(account: 'u-anne');

      expect(second.state.visible, isFalse);
      // Un hachage du compte, des compteurs : jamais un nom ni une adresse.
      final key = LocalDataNoticeCubit.acknowledgedKeyFor('u-anne');
      expect(store.entries.keys, [key]);
      expect(key, isNot(contains('anne')));
      expect(store.entries[key], matches(RegExp(r'^[a-zA-Z]+(:\d+)+$')));
    },
  );

  test('without the acknowledgement the reminder comes back', () async {
    probe.inventory = _withData;
    final cubit = cubit0();
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.load();

    expect(cubit.state.visible, isTrue);
    expect(store.entries, isEmpty);
  });

  test('a base that cannot be read keeps the reminder visible', () async {
    final cubit = LocalDataNoticeCubit(_ThrowingProbe(), store, sends);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.visible, isTrue);
  });

  test(
    'a base written by a newer version keeps the reminder visible',
    () async {
      probe.inventory = const LocalDataInventory(
        state: LocalStoreState.newerSchema,
        schemaVersion: 99,
      );
      final cubit = cubit0();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.visible, isTrue);
      expect(cubit.state.inventory.isReadable, isFalse);
    },
  );

  test('the acknowledgement is tied to what was on the device', () async {
    probe.inventory = _withData;
    final first = cubit0();
    addTearDown(first.close);
    await first.load(account: 'u-anne');
    await first.acknowledge();
    expect(first.state.visible, isFalse);

    // Même contenu au démarrage suivant : le rappel reste masqué.
    final same = cubit0();
    addTearDown(same.close);
    await same.load(account: 'u-anne');
    expect(same.state.visible, isFalse);

    // Un ancien onglet a écrit depuis : le contenu a changé, le rappel revient.
    probe.inventory = const LocalDataInventory(
      state: LocalStoreState.present,
      schemaVersion: 12,
      counts: LocalDataCounts(students: 6, attempts: 80),
    );
    final changed = cubit0();
    addTearDown(changed.close);
    await changed.load(account: 'u-anne');
    expect(changed.state.visible, isTrue);
  });

  group('the acknowledgement belongs to an account', () {
    test(
      'another account on the same device still sees the reminder',
      () async {
        probe.inventory = _withData;
        final cubit = cubit0();
        addTearDown(cubit.close);
        await cubit.load(account: 'u-anne');
        await cubit.acknowledge();
        expect(cubit.state.visible, isFalse);

        // L'enseignant B prend l'appareil : il n'a rien importé.
        await cubit.load(account: 'u-ben');
        expect(cubit.state.visible, isTrue);

        // A revient : son repère est toujours là.
        await cubit.load(account: 'u-anne');
        expect(cubit.state.visible, isFalse);
      },
    );

    test(
      'another cubit on a later start also keeps the accounts apart',
      () async {
        probe.inventory = _withData;
        final first = cubit0();
        addTearDown(first.close);
        await first.load(account: 'u-anne');
        await first.acknowledge();

        final later = cubit0();
        addTearDown(later.close);
        await later.load(account: 'u-ben');

        expect(later.state.visible, isTrue);
      },
    );

    test(
      'signed out, the reminder shows and nothing can be acknowledged',
      () async {
        probe.inventory = _withData;
        final cubit = cubit0();
        addTearDown(cubit.close);
        await cubit.load();

        expect(cubit.state.visible, isTrue);
        expect(await cubit.acknowledge(), isFalse);
        expect(store.entries, isEmpty);
      },
    );

    test('the key holds a hash, never the account identifier', () {
      final key = LocalDataNoticeCubit.acknowledgedKeyFor('u-anne@example.org');

      expect(key, startsWith('${LocalDataNoticeCubit.acknowledgedKeyPrefix}.'));
      expect(key, isNot(contains('anne')));
      expect(key, isNot(contains('@')));
      expect(key, isNot(LocalDataNoticeCubit.acknowledgedKeyFor('u-ben')));
    });
  });

  group('unsent writes', () {
    test(
      'the acknowledgement is refused while writes wait to be sent',
      () async {
        probe.inventory = _withData;
        sends.unsent = true;
        final cubit = cubit0();
        addTearDown(cubit.close);
        await cubit.load(account: 'u-anne');

        expect(await cubit.acknowledge(), isFalse);

        expect(cubit.state.visible, isTrue);
        expect(store.entries, isEmpty, reason: 'rien n est consigné');

        sends.unsent = false;
        expect(await cubit.acknowledge(), isTrue);
        expect(cubit.state.visible, isFalse);
      },
    );
  });

  group('an unreadable base cannot be acknowledged', () {
    // Son empreinte est constante (« unreadable:…:0 ») : un repère posé ici
    // masquerait le bandeau à chaque démarrage illisible suivant, alors
    // qu'aucun compteur n'a jamais été connu.
    for (final state in [
      LocalStoreState.unreadable,
      LocalStoreState.newerSchema,
    ]) {
      test(
        '${state.name}: refused, nothing recorded, reminder stays',
        () async {
          probe.inventory = LocalDataInventory(state: state, schemaVersion: 99);
          final cubit = cubit0();
          addTearDown(cubit.close);
          await cubit.load(account: 'u-anne');

          expect(await cubit.acknowledge(), isFalse);

          expect(cubit.state.visible, isTrue);
          expect(store.entries, isEmpty);
        },
      );
    }

    test('a failed read is refused as well', () async {
      final cubit = LocalDataNoticeCubit(_ThrowingProbe(), store, sends);
      addTearDown(cubit.close);
      await cubit.load(account: 'u-anne');

      expect(await cubit.acknowledge(), isFalse);

      expect(store.entries, isEmpty);
    });
  });

  test('after signing out, nothing is recorded any more', () async {
    // Le garde `account == null` n'est pas mutable seul : sans lui le code ne
    // compile pas (la clé exige un compte). Ce test fixe son comportement :
    // le compte parti, l'appel ne consigne rien de plus.
    probe.inventory = _withData;
    final cubit = cubit0();
    addTearDown(cubit.close);
    await cubit.load(account: 'u-anne');
    await cubit.load();
    final before = Map.of(store.entries);

    expect(await cubit.acknowledge(), isFalse);

    expect(store.entries, before);
    expect(cubit.state.visible, isTrue);
  });

  group('the fingerprint covers every counter', () {
    // Retirer un compteur de l'empreinte laisserait le rappel masqué alors
    // que ce contenu-là a changé : un test par compteur.
    LocalDataInventory with_(LocalDataCounts counts, {DateTime? at}) =>
        LocalDataInventory(
          state: LocalStoreState.present,
          schemaVersion: 12,
          counts: counts,
          lastModified: at,
        );

    const base = LocalDataCounts(
      students: 6,
      groups: 2,
      seasons: 1,
      sessionRecords: 3,
      attempts: 72,
      plannedSessions: 1,
      assessments: 2,
      blockAcquisitions: 4,
      seasonArchives: 1,
    );
    final variants = <String, LocalDataCounts>{
      'students': const LocalDataCounts(
        students: 7,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'groups': const LocalDataCounts(
        students: 6,
        groups: 3,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'seasons': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 2,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'sessionRecords': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 4,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'attempts': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 73,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'plannedSessions': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 2,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'assessments': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 3,
        blockAcquisitions: 4,
        seasonArchives: 1,
      ),
      'blockAcquisitions': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 5,
        seasonArchives: 1,
      ),
      'seasonArchives': const LocalDataCounts(
        students: 6,
        groups: 2,
        seasons: 1,
        sessionRecords: 3,
        attempts: 72,
        plannedSessions: 1,
        assessments: 2,
        blockAcquisitions: 4,
        seasonArchives: 2,
      ),
    };

    for (final entry in variants.entries) {
      test('a change of ${entry.key} brings the reminder back', () async {
        probe.inventory = with_(base);
        final first = cubit0();
        addTearDown(first.close);
        await first.load(account: 'u-anne');
        await first.acknowledge();
        expect(first.state.visible, isFalse);

        probe.inventory = with_(entry.value);
        final later = cubit0();
        addTearDown(later.close);
        await later.load(account: 'u-anne');

        expect(later.state.visible, isTrue);
      });
    }

    test('a later last modification brings the reminder back', () async {
      probe.inventory = with_(base, at: DateTime.utc(2026, 10));
      final first = cubit0();
      addTearDown(first.close);
      await first.load(account: 'u-anne');
      await first.acknowledge();

      probe.inventory = with_(base, at: DateTime.utc(2026, 10, 2));
      final later = cubit0();
      addTearDown(later.close);
      await later.load(account: 'u-anne');

      expect(later.state.visible, isTrue);
    });
  });
}
