import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce qu'une implémentation de [OwnMarkerStore] donne au contrat : le magasin
/// vu par le compte de [OwnMarkerHarness.scope], et de quoi poser et relire
/// un marqueur de n'importe quel auteur **sans règles** (amorçage).
final class OwnMarkerHarness {
  const OwnMarkerHarness({
    required this.store,
    required this.scope,
    required this.seed,
    required this.exists,
  });

  final OwnMarkerStore store;

  /// La session du compte courant (le contrat s'y connecte et s'en
  /// déconnecte).
  final SessionScope scope;

  final Future<void> Function(
    ClubId club,
    MarkerKind kind,
    String key,
    String author,
  )
  seed;

  final Future<bool> Function(
    ClubId club,
    MarkerKind kind,
    String key,
    String author,
  )
  exists;
}

/// Suite unique du port [OwnMarkerStore] (FB8 partie B, B1), exécutée contre
/// la mémoire et contre Firestore.
void ownMarkerStoreContract(
  String label,
  Future<OwnMarkerHarness> Function() open,
) {
  group('$label : contrat des marqueurs du compte courant', () {
    const c1 = ClubId('c1');
    const c2 = ClubId('c2');
    const me = 'u-me';
    const other = 'u-other';
    String key(int i) => i.toRadixString(16).padLeft(64, '0');

    late OwnMarkerHarness h;

    setUp(() async {
      h = await open();
      h.scope.signIn(const UserId(me));
    });

    test('lists only my markers of that kind in that club', () async {
      await h.seed(c1, MarkerKind.import, key(1), me);
      await h.seed(c1, MarkerKind.import, key(2), me);
      await h.seed(c1, MarkerKind.import, key(3), other);
      await h.seed(c1, MarkerKind.operation, key(4), me);
      await h.seed(c2, MarkerKind.import, key(5), me);

      final imports = await h.store.list(c1, MarkerKind.import);
      final operations = await h.store.list(c1, MarkerKind.operation);

      expect(imports.toSet(), {
        OwnMarker(MarkerKind.import, key(1)),
        OwnMarker(MarkerKind.import, key(2)),
      });
      expect(operations, [OwnMarker(MarkerKind.operation, key(4))]);
    });

    test('nothing to list in a club where I left nothing', () async {
      await h.seed(c1, MarkerKind.operation, key(1), other);

      expect(await h.store.list(c1, MarkerKind.operation), isEmpty);
      expect(await h.store.list(c2, MarkerKind.import), isEmpty);
    });

    test('deletes my markers and nothing else', () async {
      await h.seed(c1, MarkerKind.import, key(1), me);
      await h.seed(c1, MarkerKind.operation, key(2), me);
      await h.seed(c1, MarkerKind.import, key(3), me);
      await h.seed(c2, MarkerKind.import, key(1), me);

      await h.store.delete(c1, [
        OwnMarker(MarkerKind.import, key(1)),
        OwnMarker(MarkerKind.operation, key(2)),
      ]);

      expect(await h.exists(c1, MarkerKind.import, key(1), me), isFalse);
      expect(await h.exists(c1, MarkerKind.operation, key(2), me), isFalse);
      expect(await h.exists(c1, MarkerKind.import, key(3), me), isTrue);
      expect(await h.exists(c2, MarkerKind.import, key(1), me), isTrue);
    });

    test(
      'never deletes the marker another author left for the same key',
      () async {
        await h.seed(c1, MarkerKind.import, key(1), me);
        await h.seed(c1, MarkerKind.import, key(1), other);
        await h.seed(c1, MarkerKind.operation, key(2), other);

        await h.store.delete(c1, [
          OwnMarker(MarkerKind.import, key(1)),
          OwnMarker(MarkerKind.operation, key(2)),
        ]);

        expect(await h.exists(c1, MarkerKind.import, key(1), me), isFalse);
        expect(await h.exists(c1, MarkerKind.import, key(1), other), isTrue);
        expect(await h.exists(c1, MarkerKind.operation, key(2), other), isTrue);
      },
    );

    test('deleting a marker already gone is not an error (resume)', () async {
      await h.store.delete(c1, [OwnMarker(MarkerKind.import, key(9))]);
      await h.store.delete(c1, const []);

      expect(await h.store.list(c1, MarkerKind.import), isEmpty);
    });

    test(
      'a lot of more than $maxOwnMarkerLot deletions is refused whole',
      () async {
        await h.seed(c1, MarkerKind.import, key(0), me);
        final markers = [
          for (var i = 0; i <= maxOwnMarkerLot; i++)
            OwnMarker(MarkerKind.import, key(i)),
        ];

        await expectLater(
          h.store.delete(c1, markers),
          throwsA(isA<ServiceFailure>()),
        );
        expect(await h.exists(c1, MarkerKind.import, key(0), me), isTrue);
      },
    );

    test('without an account, nothing is read or written', () async {
      await h.seed(c1, MarkerKind.import, key(1), me);
      h.scope.signOut();

      await expectLater(
        h.store.list(c1, MarkerKind.import),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
      await expectLater(
        h.store.delete(c1, [OwnMarker(MarkerKind.import, key(1))]),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
      expect(await h.exists(c1, MarkerKind.import, key(1), me), isTrue);
    });
  });
}
