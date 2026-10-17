import 'package:billard_cfa/entities/club/data/store_club_repository.dart';
import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryDocumentStore store;
  late StoreClubRepository clubs;
  final now = DateTime(2026, 10, 12, 9, 30);

  setUp(() {
    store = InMemoryDocumentStore()..serverNow = () => now;
    clubs = StoreClubRepository(store);
  });

  test('creates a club document with a server date', () async {
    await clubs.create(Club(id: const ClubId('c1'), name: 'Club Nice'));

    expect(store.read('clubs/c1'), {'name': 'Club Nice', 'createdAt': now});
    expect(
      await clubs.byId(const ClubId('c1')),
      Club(id: const ClubId('c1'), name: 'Club Nice'),
    );
  });

  test('stores the current season when there is one', () async {
    await clubs.create(
      Club(
        id: const ClubId('c1'),
        name: 'N',
        currentSeasonId: const SeasonId('s1'),
      ),
    );
    expect(store.read('clubs/c1')!['currentSeasonId'], 's1');
    expect(
      (await clubs.byId(const ClubId('c1')))!.currentSeasonId,
      const SeasonId('s1'),
    );
  });

  test('lists every club, ignoring an unreadable document', () async {
    await clubs.create(Club(id: const ClubId('b'), name: 'Beta'));
    await clubs.create(Club(id: const ClubId('a'), name: 'Alpha'));
    store
      ..seed('clubs/x', {'createdAt': now})
      ..seed('clubs/y', {'name': 'é' * 200});

    final all = await clubs.all();

    expect([for (final c in all) c.name], ['Alpha', 'Beta']);
  });

  test('an unknown club is null', () async {
    expect(await clubs.byId(const ClubId('nope')), isNull);
  });

  test('renames with an update that touches only the name', () async {
    await clubs.create(Club(id: const ClubId('c1'), name: 'Club Nice'));

    await clubs.rename(const ClubId('c1'), '  Club Lyon ');

    expect(store.read('clubs/c1'), {'name': 'Club Lyon', 'createdAt': now});
  });

  test('renaming validates the name and leaves the document alone', () async {
    await clubs.create(Club(id: const ClubId('c1'), name: 'Club Nice'));

    await expectLater(
      clubs.rename(const ClubId('c1'), ' '),
      throwsA(isA<InvariantViolation>()),
    );
    expect(store.read('clubs/c1')!['name'], 'Club Nice');
  });

  test('renaming an unknown club is a service failure, not a crash', () async {
    await expectLater(
      clubs.rename(const ClubId('nope'), 'X'),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.code,
          'code',
          ServiceFailureCode.other,
        ),
      ),
    );
  });

  test('every failure of the store becomes a ServiceFailure', () async {
    store.failing = StoreFailureCode.permissionDenied;
    await expectLater(
      clubs.all(),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.code,
          'code',
          ServiceFailureCode.denied,
        ),
      ),
    );
    store.failing = StoreFailureCode.unavailable;
    await expectLater(
      clubs.byId(const ClubId('c1')),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });
}
