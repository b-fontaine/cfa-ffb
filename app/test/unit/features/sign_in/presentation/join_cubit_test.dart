import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_failure.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/features/sign_in/domain/accept_invitation.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_cubit.dart';
import 'package:billard_cfa/features/sign_in/presentation/bloc/join_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';

void main() {
  late ClubWorld world;
  late JoinCubit cubit;
  final code = InvitationCode.tryParse('GUARDIANCODE')!;

  Future<void> invite({Duration validity = const Duration(days: 7)}) =>
      world.invitations.create(
        Invitation(
          code: code,
          clubId: ClubWorld.club,
          role: Role.guardian,
          createdBy: ClubWorld.director,
          createdAt: world.clock.now(),
          expiresAt: world.clock.now().add(validity),
          groupIds: const [GroupId('g1')],
          studentIds: const [StudentId('s1')],
        ),
      );

  setUp(() async {
    world = ClubWorld();
    world.scope.signIn(const UserId('u-anne'));
    cubit = JoinCubit(
      AcceptInvitation(
        world.invitations,
        KeyValuePendingInvitations(world.keyValues),
        world.scope,
      ),
    );
    await invite();
  });

  tearDown(() => cubit.close());

  Future<JoinState> join({String? text, String name = 'Anne'}) async {
    await cubit.submit(code: text ?? 'GUARDIANCODE', name: name);
    return cubit.state;
  }

  test('starts editing', () {
    expect(cubit.state, const JoinState());
  });

  test('joins the club', () async {
    expect((await join()).status, JoinStatus.done);
    expect(world.doc('clubs/c1/members/u-anne'), isNotNull);
  });

  test('goes through submitting, then done', () async {
    final states = <JoinStatus>[];
    cubit.stream.listen((s) => states.add(s.status));

    await join();
    await pumpEventQueue();

    expect(states, [JoinStatus.submitting, JoinStatus.done]);
  });

  test('every refusal has its own code', () async {
    final cases = <(String, String, JoinFailureCode)>[
      ('court', 'Anne', JoinFailureCode.invalidCode),
      ('UNKNOWNCODEX', 'Anne', JoinFailureCode.notFound),
      ('GUARDIANCODE', ' ', JoinFailureCode.name),
      ('GUARDIANCODE', 'é' * 41, JoinFailureCode.name),
    ];
    for (final (text, name, expected) in cases) {
      final state = await join(text: text, name: name);
      expect(state.status, JoinStatus.failed, reason: '$text/$name');
      expect(state.failure, expected, reason: '$text/$name');
    }
  });

  test('an expired, a used and a refused invitation', () async {
    world.clock.advance(const Duration(days: 8));
    expect((await join()).failure, JoinFailureCode.expired);

    world.clock.advance(const Duration(days: -8));
    world.store.seed('invitations/GUARDIANCODE', {
      ...world.doc('invitations/GUARDIANCODE')!,
      'used': true,
    });
    expect((await join()).failure, JoinFailureCode.used);

    world.store.seed('invitations/GUARDIANCODE', {
      ...world.doc('invitations/GUARDIANCODE')!,
      'used': false,
    });
    final denying = _DenyingRepository(world.invitations);
    final refused = JoinCubit(
      AcceptInvitation(
        denying,
        KeyValuePendingInvitations(world.keyValues),
        world.scope,
      ),
    );
    addTearDown(refused.close);
    await refused.submit(code: 'GUARDIANCODE', name: 'Anne');
    expect(refused.state.failure, JoinFailureCode.refused);
  });

  test(
    'an unreachable service is reported as such, a denial as refused',
    () async {
      world.store.failing = StoreFailureCode.unavailable;
      expect((await join()).failure, JoinFailureCode.unavailable);

      world.store.failing = StoreFailureCode.permissionDenied;
      expect((await join()).failure, JoinFailureCode.refused);

      world.store.failing = StoreFailureCode.other;
      expect((await join()).failure, JoinFailureCode.unavailable);
    },
  );

  test('somebody not signed in is refused', () async {
    world.scope.signOut();
    expect((await join()).failure, JoinFailureCode.refused);
  });

  test('a second submit while the first one runs is ignored', () async {
    final first = cubit.submit(code: 'GUARDIANCODE', name: 'Anne');
    final second = cubit.submit(code: 'GUARDIANCODE', name: 'Anne');
    await Future.wait([first, second]);

    expect(cubit.state.status, JoinStatus.done);
    expect(
      world.store.documents.keys.where((p) => p.contains('/members/')),
      hasLength(1),
    );
  });

  test('nothing is emitted once the cubit is closed', () async {
    final pending = cubit.submit(code: 'GUARDIANCODE', name: 'Anne');
    await cubit.close();
    await pending;
    expect(cubit.isClosed, isTrue);
  });
}

/// Dépôt qui accepte la lecture mais dont le lot est refusé par les règles.
class _DenyingRepository implements InvitationRepository {
  _DenyingRepository(this._inner);

  final InvitationRepository _inner;

  @override
  Future<void> accept({
    required InvitationCode code,
    required UserId user,
    required String displayName,
  }) => throw const InvitationFailure(InvitationFailureCode.refused);

  @override
  Future<void> create(Invitation invitation) => _inner.create(invitation);

  @override
  Future<Invitation?> find(InvitationCode code) => _inner.find(code);

  @override
  Future<void> revoke(InvitationCode code) => _inner.revoke(code);
}
