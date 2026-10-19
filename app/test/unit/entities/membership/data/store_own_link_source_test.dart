import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/membership/data/store_own_link_source.dart';
import 'package:billard_cfa/entities/membership/domain/own_link.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/firestore_world.dart';
import '../../../../support/stream_log.dart';

void main() {
  late FirestoreWorld world;
  late StoreOwnLinkSource source;
  const path = 'clubs/c1/members/u-dir';

  setUp(() {
    world = FirestoreWorld()..act('c1', Role.guardian);
    source = StoreOwnLinkSource(world.club, world.scope);
    world.documents.seed(path, {
      'uid': 'u-dir',
      'role': 'guardian',
      'displayName': 'Anne',
      'groupIds': ['g1', ''],
      'studentIds': ['s1', 's2', 7],
    });
  });

  group('read', () {
    test(
      'gives the role, the linked students and the groups of the member',
      () async {
        final link = (await source.read())!;

        expect(link.role, Role.guardian);
        expect(link.studentIds, {const StudentId('s1'), const StudentId('s2')});
        expect(link.groupIds, {const GroupId('g1')});
      },
    );

    test('is null once the member is gone', () async {
      world.documents.remove(path);

      expect(await source.read(), isNull);
    });

    test('is null for a role it does not know', () async {
      world.documents.seed(path, {'uid': 'u-dir', 'role': 'wizard'});

      expect(await source.read(), isNull);
    });

    test(
      'is null when the rules refuse the read (a deleted member is refused)',
      () async {
        world.documents.revoke('clubs/c1/');

        expect(await source.read(), isNull);
      },
    );

    test(
      'an unreachable service is an unavailable failure, not a removed access',
      () async {
        world.documents.failing = StoreFailureCode.unavailable;

        await expectLater(
          source.read(),
          throwsA(
            isA<ServiceFailure>().having(
              (e) => e.code,
              'code',
              ServiceFailureCode.unavailable,
            ),
          ),
        );
      },
    );

    test('without a signed-in user the access is denied', () async {
      final nobody = StoreOwnLinkSource(world.club, SessionScope());

      await expectLater(
        nobody.read(),
        throwsA(
          isA<ServiceFailure>().having(
            (e) => e.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );
    });
  });

  group('watch', () {
    test('follows the link and says null when the member disappears', () async {
      final log = StreamLog<OwnLink?>(source.watch());
      await log.settle();
      expect(log.values.single!.studentIds, hasLength(2));

      world.documents.seed(path, {
        'uid': 'u-dir',
        'role': 'guardian',
        'displayName': 'Anne',
        'groupIds': ['g1'],
        'studentIds': ['s1'],
      });
      await log.settle();
      expect(log.last!.studentIds, {const StudentId('s1')});

      world.documents.remove(path);
      await log.settle();
      expect(log.last, isNull);
      await log.cancel();
    });

    test(
      'a refusal arrives on the stream as a denied failure, and it closes',
      () async {
        final log = StreamLog<OwnLink?>(source.watch());
        await log.settle();

        world.documents.revoke('clubs/c1/');
        await log.settle();

        expect(
          log.errors.single,
          isA<ServiceFailure>().having(
            (e) => e.code,
            'code',
            ServiceFailureCode.denied,
          ),
        );
        expect(log.done, isTrue);
      },
    );

    test('releases the listener when cancelled', () async {
      final log = StreamLog<OwnLink?>(source.watch());
      await log.settle();
      expect(world.documents.activeWatchers, 1);

      await log.cancel();

      expect(world.documents.activeWatchers, 0);
    });
  });
}
