import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un magasin scripté : les marqueurs rendus par nature, et chaque appel noté.
class _Store implements OwnMarkerStore {
  _Store({this.imports = 0, this.operations = 0, this.failOnDelete});

  final int imports;
  final int operations;

  /// Le lot d'indice [failOnDelete] (à partir de 0) échoue (`unavailable`).
  final int? failOnDelete;

  final List<String> calls = [];
  final List<List<OwnMarker>> deleted = [];

  static String key(int i) => i.toRadixString(16).padLeft(64, '0');

  @override
  Future<List<OwnMarker>> list(ClubId club, MarkerKind kind) async {
    calls.add('list ${club.value} ${kind.name}');
    final count = kind == MarkerKind.import ? imports : operations;
    final offset = kind == MarkerKind.import ? 0 : 100000;
    return [for (var i = 0; i < count; i++) OwnMarker(kind, key(offset + i))];
  }

  @override
  Future<void> delete(ClubId club, List<OwnMarker> markers) async {
    calls.add('delete ${club.value} ${markers.length}');
    if (failOnDelete == deleted.length) {
      throw const ServiceFailure(ServiceFailureCode.unavailable, 'coupure');
    }
    deleted.add(markers);
  }
}

void main() {
  const club = ClubId('c1');

  test('a teacher lists and deletes only import markers', () async {
    final store = _Store(imports: 2, operations: 3);

    final removed = await RemoveOwnMarkers(store).call(club, Role.teacher);

    expect(removed, 2);
    expect(store.calls, ['list c1 import', 'delete c1 2']);
    expect(store.deleted.single, [
      OwnMarker(MarkerKind.import, _Store.key(0)),
      OwnMarker(MarkerKind.import, _Store.key(1)),
    ]);
  });

  for (final role in [Role.director, Role.admin]) {
    test(
      'a ${role.name} deletes import markers, then operation markers',
      () async {
        final store = _Store(imports: 1, operations: 2);

        final removed = await RemoveOwnMarkers(store).call(club, role);

        expect(removed, 3);
        expect(store.calls, [
          'list c1 import',
          'delete c1 1',
          'list c1 operation',
          'delete c1 2',
        ]);
        expect(
          store.deleted.last.map((m) => m.kind),
          everyElement(MarkerKind.operation),
        );
      },
    );
  }

  for (final role in [Role.guardian, Role.student]) {
    test(
      'a ${role.name} holds no marker: nothing is read or written',
      () async {
        final store = _Store(imports: 2, operations: 2);

        final removed = await RemoveOwnMarkers(store).call(club, role);

        expect(removed, 0);
        expect(store.calls, isEmpty);
      },
    );
  }

  test('no marker found: no lot is sent', () async {
    final store = _Store();

    expect(await RemoveOwnMarkers(store).call(club, Role.director), 0);
    expect(store.calls, ['list c1 import', 'list c1 operation']);
  });

  test('markers are deleted in lots of 400 at most', () async {
    final store = _Store(imports: 801);

    final removed = await RemoveOwnMarkers(store).call(club, Role.teacher);

    expect(removed, 801);
    expect(store.deleted.map((lot) => lot.length), [400, 400, 1]);
    expect(store.deleted.expand((lot) => lot).toSet(), hasLength(801));
  });

  test('exactly 400 markers make a single lot', () async {
    final store = _Store(imports: 400);

    await RemoveOwnMarkers(store).call(club, Role.teacher);

    expect(store.deleted.map((lot) => lot.length), [400]);
  });

  test('a failed lot stops the cleanup and is reported', () async {
    final store = _Store(imports: 450, operations: 1, failOnDelete: 1);

    await expectLater(
      RemoveOwnMarkers(store).call(club, Role.director),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
    expect(store.calls, ['list c1 import', 'delete c1 400', 'delete c1 50']);
  });

  test('the roles that hold each kind follow the rules', () {
    expect(
      [
        for (final r in Role.values)
          if (MarkerKind.import.heldBy(r)) r,
      ],
      [Role.teacher, Role.director, Role.admin],
    );
    expect(
      [
        for (final r in Role.values)
          if (MarkerKind.operation.heldBy(r)) r,
      ],
      [Role.director, Role.admin],
    );
  });
}
