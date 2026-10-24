import 'dart:async';

import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/auth/local_data_guard.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/membership/data/key_value_active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_rig.dart';

const _nice = ClubMembership(
  clubId: ClubId('nice'),
  clubName: 'Club Nice',
  role: Role.director,
);
const _lyon = ClubMembership(
  clubId: ClubId('lyon'),
  clubName: 'Club Lyon',
  role: Role.teacher,
);

/// Dépôt dont le flux des comptes échoue.
class _BrokenAuth implements AuthRepository {
  @override
  Stream<Account?> watchAccount() => Stream.error(StateError('flux cassé'));

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> register({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> reauthenticate(String password) => throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

/// Démarrage dont l'attente ne se termine jamais.
class _NeverReady implements SessionStartup {
  @override
  Future<bool> get ready => Completer<bool>().future;

  @override
  Future<bool> retry() => Completer<bool>().future;
}

/// Dépôt dont le flux des comptes n'émet rien (SDK qui ne répond pas).
class _SilentAuth extends InMemoryAuthRepository {
  final StreamController<Account?> silent =
      StreamController<Account?>.broadcast();

  @override
  Stream<Account?> watchAccount() => silent.stream;
}

/// Dépôt dont la fermeture de session échoue.
class _SignOutFails extends InMemoryAuthRepository {
  @override
  Future<void> signOut() =>
      throw const AuthFailure(AuthFailureCode.unavailable);
}

/// Appartenances dont la lecture lève une erreur inattendue.
class _ExplodingMemberships implements MembershipsSource {
  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) =>
      throw StateError('clubs illisibles');

  @override
  Future<bool> isAdmin(UserId user) => throw StateError('clubs illisibles');

  @override
  Future<List<OwnMember>> ownMembers(UserId user) =>
      throw StateError('clubs illisibles');
}

/// Stockage local dont la lecture lève une erreur inattendue.
class _ExplodingStore extends InMemoryKeyValueStore {
  @override
  Future<String?> read(String key) => throw StateError('stockage illisible');
}

void main() {
  late AuthRig rig;
  late Account coach;

  setUp(() {
    rig = AuthRig();
    coach = rig.auth.seed(email: 'coach@example.org', password: 'pw');
    addTearDown(rig.cubit.close);
  });

  Future<void> settle() => pumpEventQueue();

  group('start', () {
    test('is unknown until started', () {
      expect(rig.cubit.state, const AuthUnknown());
    });

    test('nobody on the device: signed out', () async {
      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthSignedOut());
      expect(rig.scope.id, isNull);
    });

    test(
      'a persisted session with a single club opens it and remembers it',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);

        await rig.cubit.start();
        await settle();

        expect(
          rig.cubit.state,
          AuthReady(account: coach, club: _nice, choices: const [_nice]),
        );
        expect(rig.scope.id, coach.id);
        expect(rig.scope.clubId, _nice.clubId);
        expect(rig.scope.role, Role.director);
        expect(await rig.memory.read(coach.id), _nice);
      },
    );

    test('is idempotent', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);

      await rig.cubit.start();
      await rig.cubit.start();
      await settle();

      expect(rig.memberships.reads, 1);
    });

    test('a service that does not start is unavailable', () async {
      rig.startup.available = false;

      await rig.cubit.start();

      expect(rig.cubit.state, const AuthIndisponible());
    });

    test('an unverified account is treated as signed out', () async {
      final unverified = rig.auth.seed(
        email: 'new@example.org',
        password: 'pw',
        emailVerified: false,
      );
      rig.auth.restoreSession('new@example.org');
      rig.memberships.grant(unverified.id, _nice);

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthSignedOut());
    });

    test('a failing account stream is unavailable', () async {
      final cubit = AuthCubit(
        rig.startup,
        _BrokenAuth(),
        rig.memberships,
        rig.memory,
        rig.chooseClub,
        rig.scope,
        rig.pending,
        rig.issued,
        rig.reloadRules,
        rig.local,
        rig.deleteOwnAccount,
      );
      addTearDown(cubit.close);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await cubit.start();
      await settle();

      expect(cubit.state, const AuthIndisponible());
      expect(reported, hasLength(1));
    });
  });

  group('clubs', () {
    test(
      'no club: noClub without choices, and the memory is cleared',
      () async {
        await rig.memory.write(coach.id, _nice);
        rig.auth.restoreSession('coach@example.org');

        await rig.cubit.start();
        await settle();

        expect(rig.cubit.state, AuthNoClub(account: coach, choices: const []));
        expect(rig.scope.id, coach.id);
        expect(rig.scope.clubId, isNull);
        expect(await rig.memory.read(coach.id), isNull);
      },
    );

    test(
      'several clubs and none remembered: noClub with the choices',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships
          ..grant(coach.id, _nice)
          ..grant(coach.id, _lyon);

        await rig.cubit.start();
        await settle();

        expect(
          rig.cubit.state,
          AuthNoClub(account: coach, choices: const [_nice, _lyon]),
        );
      },
    );

    test('a remembered club among several opens without asking', () async {
      await rig.memory.write(coach.id, _lyon);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(coach.id, _lyon);

      await rig.cubit.start();
      await settle();

      final state = rig.cubit.state as AuthReady;
      expect(state.club, _lyon);
      expect(state.canSwitchClub, isTrue);
      expect(rig.scope.clubId, _lyon.clubId);
    });

    test('choosing a club from noClub opens it and remembers it', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(coach.id, _lyon);
      await rig.cubit.start();
      await settle();

      final chosen = await rig.cubit.chooseClub(_lyon);

      expect(chosen, isTrue);
      expect(
        rig.cubit.state,
        AuthReady(account: coach, club: _lyon, choices: const [_nice, _lyon]),
      );
      expect(await rig.memory.read(coach.id), _lyon);
      expect(rig.scope.clubId, _lyon.clubId);
    });

    test('switching club is refused while the guard blocks', () async {
      await rig.memory.write(coach.id, _nice);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(coach.id, _lyon);
      await rig.cubit.start();
      await settle();
      rig.guard.isBlocked = true;

      final chosen = await rig.cubit.chooseClub(_lyon);

      expect(chosen, isFalse);
      expect((rig.cubit.state as AuthReady).club, _nice);
      expect(await rig.memory.read(coach.id), _nice);
      expect(rig.scope.clubId, _nice.clubId);
    });

    test('switching club when allowed replaces the active club', () async {
      await rig.memory.write(coach.id, _nice);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(coach.id, _lyon);
      await rig.cubit.start();
      await settle();

      expect(await rig.cubit.chooseClub(_lyon), isTrue);

      expect((rig.cubit.state as AuthReady).club, _lyon);
      expect(rig.scope.role, Role.teacher);
    });

    test('choosing without a session does nothing', () async {
      await rig.cubit.start();
      await settle();

      expect(await rig.cubit.chooseClub(_nice), isFalse);
      expect(rig.cubit.state, const AuthSignedOut());
    });

    test('refresh picks up a club granted since', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await settle();
      expect(rig.cubit.state, isA<AuthNoClub>());

      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.refresh();

      expect((rig.cubit.state as AuthReady).club, _nice);
    });

    test('refresh does nothing before a session is known', () async {
      await rig.cubit.refresh();

      expect(rig.cubit.state, const AuthUnknown());
      expect(rig.memberships.reads, 0);
    });
  });

  group('offline start with a persisted session', () {
    test('opens the club remembered on the device', () async {
      await rig.memory.write(coach.id, _lyon);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.unavailable = true;

      await rig.cubit.start();
      await settle();

      expect(
        rig.cubit.state,
        AuthReady(account: coach, club: _lyon, choices: const [_lyon]),
      );
      expect(rig.scope.clubId, _lyon.clubId);
    });

    test('without a remembered club it is unavailable', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.unavailable = true;

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthIndisponible());
      expect(rig.scope.clubId, isNull);
    });

    test('retry reads the clubs again once the network is back', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..unavailable = true;
      await rig.cubit.start();
      await settle();
      expect(rig.cubit.state, const AuthIndisponible());

      rig.memberships.unavailable = false;
      await rig.cubit.retry();
      await settle();

      expect((rig.cubit.state as AuthReady).club, _nice);
    });
  });

  group('clubs refused by the server', () {
    late DebugPrintCallback previous;
    late List<String> logged;

    setUp(() {
      previous = debugPrint;
      logged = [];
      debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    });

    tearDown(() => debugPrint = previous);

    test('are access denied, with no club active', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..denied = true;

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthAccessDenied());
      expect(rig.scope.clubId, isNull);
      expect(rig.cubit.hasSession, isTrue);
    });

    test('do not fall back on the club remembered on the device', () async {
      await rig.memory.write(coach.id, _lyon);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.denied = true;

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthAccessDenied());
      expect(rig.scope.clubId, isNull);
    });

    test('are logged once, without any e-mail or uid', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.denied = true;

      await rig.cubit.start();
      await settle();

      expect(logged, hasLength(1));
      expect(logged.single, contains('MembershipsDenied'));
      expect(logged.single, isNot(contains('coach@example.org')));
      expect(logged.single, isNot(contains(coach.id.value)));
    });

    test('a refusal on a refresh clears the whole club scope', () async {
      const teaching = ClubMembership(
        clubId: ClubId('nice'),
        clubName: 'Club Nice',
        role: Role.teacher,
        groupIds: [GroupId('g1')],
      );
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, teaching);
      await rig.cubit.start();
      await settle();
      expect(rig.scope.clubId, teaching.clubId);
      expect(rig.scope.groupIds, [const GroupId('g1')]);

      rig.memberships.denied = true;
      await rig.cubit.refresh();

      expect(rig.cubit.state, const AuthAccessDenied());
      expect(rig.scope.clubId, isNull);
      expect(rig.scope.role, isNull);
      expect(rig.scope.groupIds, isEmpty);
    });

    test('a refresh once access is back opens the club', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..grant(coach.id, _nice)
        ..denied = true;
      await rig.cubit.start();
      await settle();

      rig.memberships.denied = false;
      await rig.cubit.refresh();

      expect((rig.cubit.state as AuthReady).club, _nice);
    });

    test('signing out leaves the denied screen', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.denied = true;
      await rig.cubit.start();
      await settle();

      await rig.cubit.signOut();

      expect(rig.cubit.state, const AuthSignedOut());
    });
  });

  group('retry', () {
    test('after a failed start, tries the service again', () async {
      rig.startup.available = false;
      await rig.cubit.start();
      expect(rig.cubit.state, const AuthIndisponible());

      rig.startup.available = true;
      await rig.cubit.retry();
      await settle();

      expect(rig.cubit.state, const AuthSignedOut());
    });

    test('stays unavailable while the service is still down', () async {
      rig.startup.available = false;
      await rig.cubit.start();

      await rig.cubit.retry();

      expect(rig.cubit.state, const AuthIndisponible());
    });
  });

  group('sign-in and sign-out', () {
    test('signing in later opens the app', () async {
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      expect(rig.cubit.state, const AuthSignedOut());

      await rig.auth.signIn(email: 'coach@example.org', password: 'pw');
      await settle();

      expect((rig.cubit.state as AuthReady).club, _nice);
    });

    test('signing out forgets the remembered club and the scope', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      expect(await rig.memory.read(coach.id), _nice);

      await rig.cubit.signOut();
      await settle();

      expect(rig.cubit.state, const AuthSignedOut());
      expect(rig.scope.id, isNull);
      expect(rig.scope.clubId, isNull);
      expect(await rig.memory.read(coach.id), isNull);
      expect(rig.auth.current, isNull);
    });

    test(
      'a refused sign-out changes nothing: still in the club, memory kept',
      () async {
        final auth = _SignOutFails();
        final account = auth.seed(email: 'coach@example.org', password: 'pw');
        auth.restoreSession('coach@example.org');
        rig.memberships.grant(account.id, _nice);
        final cubit = AuthCubit(
          rig.startup,
          auth,
          rig.memberships,
          rig.memory,
          rig.chooseClub,
          rig.scope,
          rig.pending,
          rig.issued,
          rig.reloadRules,
          rig.local,
          rig.deleteOwnAccount,
        );
        addTearDown(cubit.close);
        await cubit.start();
        await settle();
        final before = cubit.state;
        expect(before, isA<AuthReady>());

        await cubit.signOut();
        await settle();

        expect(cubit.state, before);
        expect(rig.scope.id, account.id);
        expect(rig.scope.clubId, _nice.clubId);
        expect(await rig.memory.read(account.id), _nice);
        expect(auth.current, account);
      },
    );

    test('a user who is not the signed-in one keeps their memory', () async {
      final other = rig.auth.seed(email: 'other@example.org', password: 'pw');
      await rig.memory.write(other.id, _lyon);
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();

      await rig.cubit.signOut();

      expect(await rig.memory.read(other.id), _lyon);
    });
  });

  test('a late answer for a previous account is dropped', () async {
    final slow = Completer<List<ClubMembership>>();
    final cubit = AuthCubit(
      rig.startup,
      rig.auth,
      SlowMemberships(slow.future, rig.memberships),
      rig.memory,
      rig.chooseClub,
      rig.scope,
      rig.pending,
      rig.issued,
      rig.reloadRules,
      rig.local,
      rig.deleteOwnAccount,
    );
    addTearDown(cubit.close);
    final other = rig.auth.seed(email: 'other@example.org', password: 'pw');
    rig.memberships.grant(other.id, _lyon);
    rig.auth.restoreSession('coach@example.org');

    await cubit.start();
    await settle();
    // Le premier compte attend encore ses clubs : l'autre se connecte.
    await rig.auth.signIn(email: 'other@example.org', password: 'pw');
    await settle();
    slow.complete([_nice]);
    await settle();

    expect((cubit.state as AuthReady).club, _lyon);
    expect(rig.scope.id, other.id);
  });

  test('states have value equality and a stable hash', () {
    final account = coach;
    expect(const AuthUnknown().hashCode, const AuthUnknown().hashCode);
    expect(const AuthSignedOut().hashCode, const AuthSignedOut().hashCode);
    expect(
      const AuthIndisponible().hashCode,
      const AuthIndisponible().hashCode,
    );
    expect(
      AuthNoClub(account: account, choices: const [_nice]).hashCode,
      AuthNoClub(account: account, choices: const [_nice]).hashCode,
    );
    expect(
      AuthReady(account: account, club: _nice, choices: const [_nice]),
      AuthReady(account: account, club: _nice, choices: const [_nice]),
    );
    expect(
      AuthReady(account: account, club: _nice, choices: const [_nice]),
      isNot(AuthReady(account: account, club: _lyon, choices: const [_nice])),
    );
    expect(
      AuthReady(account: account, club: _nice, choices: const [_nice]).hashCode,
      AuthReady(account: account, club: _nice, choices: const [_nice]).hashCode,
    );
  });

  group('an unexpected error while resolving the clubs', () {
    late FlutterExceptionHandler? previous;
    late List<FlutterErrorDetails> reported;

    setUp(() {
      previous = FlutterError.onError;
      reported = [];
      FlutterError.onError = reported.add;
    });

    tearDown(() => FlutterError.onError = previous);

    test(
      'from the clubs source: unavailable, no club, reported once',
      () async {
        rig.auth.restoreSession('coach@example.org');
        final cubit = AuthCubit(
          rig.startup,
          rig.auth,
          _ExplodingMemberships(),
          rig.memory,
          rig.chooseClub,
          rig.scope,
          rig.pending,
          rig.issued,
          rig.reloadRules,
          rig.local,
          rig.deleteOwnAccount,
        );
        addTearDown(cubit.close);

        await cubit.start();
        await settle();

        expect(cubit.state, const AuthIndisponible());
        expect(rig.scope.id, coach.id);
        expect(rig.scope.clubId, isNull);
        expect(reported, hasLength(1));
        expect(reported.single.exception, isA<StateError>());
        expect(reported.single.library, 'auth_cubit');
      },
    );

    test(
      'from the device memory: unavailable, no club, reported once',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        final memory = KeyValueActiveClubMemory(_ExplodingStore());
        final cubit = AuthCubit(
          rig.startup,
          rig.auth,
          rig.memberships,
          memory,
          ChooseClub(memory, rig.guard),
          rig.scope,
          rig.pending,
          rig.issued,
          rig.reloadRules,
          rig.local,
          rig.deleteOwnAccount,
        );
        addTearDown(cubit.close);

        await cubit.start();
        await settle();

        expect(cubit.state, const AuthIndisponible());
        expect(rig.scope.clubId, isNull);
        expect(reported, hasLength(1));
        expect(reported.single.exception, isA<StateError>());
      },
    );
  });

  group('startup that never answers', () {
    AuthCubit build(AuthRepository auth, SessionStartup startup) {
      final cubit = AuthCubit(
        startup,
        auth,
        rig.memberships,
        rig.memory,
        rig.chooseClub,
        rig.scope,
        rig.pending,
        rig.issued,
        rig.reloadRules,
        rig.local,
        rig.deleteOwnAccount,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    const wait = Duration(seconds: 20);

    testWidgets(
      'the service never initialises: unavailable, not a splash for ever',
      (tester) async {
        final cubit = build(rig.auth, _NeverReady());
        unawaited(cubit.start());
        await tester.pump(wait - const Duration(seconds: 1));
        expect(cubit.state, const AuthUnknown());

        await tester.pump(const Duration(seconds: 2));

        expect(cubit.state, const AuthIndisponible());
      },
    );

    testWidgets('the account stream never emits: unavailable', (tester) async {
      final cubit = build(_SilentAuth(), rig.startup);
      unawaited(cubit.start());
      await tester.pump(wait - const Duration(seconds: 1));
      expect(cubit.state, const AuthUnknown());

      await tester.pump(const Duration(seconds: 2));

      expect(cubit.state, const AuthIndisponible());
    });

    testWidgets('an answer in time cancels the wait', (tester) async {
      final cubit = build(rig.auth, rig.startup);
      unawaited(cubit.start());
      await tester.pump();
      expect(cubit.state, const AuthSignedOut());

      await tester.pump(wait * 2);

      expect(cubit.state, const AuthSignedOut());
    });

    testWidgets('a late first account still opens the app', (tester) async {
      final auth = _SilentAuth();
      final account = auth.seed(email: 'coach@example.org', password: 'pw');
      rig.memberships.grant(account.id, _nice);
      final cubit = build(auth, rig.startup);
      unawaited(cubit.start());
      await tester.pump(wait + const Duration(seconds: 1));
      expect(cubit.state, const AuthIndisponible());

      auth.silent.add(account);
      await tester.pump();

      expect(cubit.state, isA<AuthReady>());
    });

    testWidgets('retry waits again from the start', (tester) async {
      final cubit = build(_SilentAuth(), rig.startup);
      unawaited(cubit.start());
      await tester.pump(wait + const Duration(seconds: 1));
      expect(cubit.state, const AuthIndisponible());

      unawaited(cubit.retry());
      await tester.pump();
      expect(cubit.state, const AuthUnknown());
      await tester.pump(wait - const Duration(seconds: 1));
      expect(cubit.state, const AuthUnknown());
      await tester.pump(const Duration(seconds: 2));

      expect(cubit.state, const AuthIndisponible());
    });
  });

  group('hasSession', () {
    test('is false before and without an account, true with one', () async {
      expect(rig.cubit.hasSession, isFalse);

      await rig.cubit.start();
      await settle();
      expect(rig.cubit.hasSession, isFalse);
    });

    test(
      'is true when the clubs of a signed-in account cannot be read',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.unavailable = true;

        await rig.cubit.start();
        await settle();

        expect(rig.cubit.state, const AuthIndisponible());
        expect(rig.cubit.hasSession, isTrue);
      },
    );

    test('is false again after signing out', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();

      await rig.cubit.signOut();

      expect(rig.cubit.hasSession, isFalse);
    });
  });

  group('local data cache (C4)', () {
    test(
      'the cache is claimed by the account before its clubs are read',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);

        await rig.cubit.start();
        await settle();

        expect(rig.store.entries['firestore_cache_owner'], coach.id.value);
        expect(rig.cache.clears, 0);
        expect(rig.cubit.state, isA<AuthReady>());
      },
    );

    test('another account on the device clears the previous cache and puts '
        'the store back in service', () async {
      final other = rig.auth.seed(email: 'other@example.org', password: 'pw');
      rig.memberships
        ..grant(coach.id, _nice)
        ..grant(other.id, _lyon);
      await rig.store.write('firestore_cache_owner', coach.id.value);
      rig.auth.restoreSession('other@example.org');

      await rig.cubit.start();
      await settle();

      expect(rig.cache.clears, 1);
      expect(rig.cache.reopens, 1);
      expect(rig.store.entries['firestore_cache_owner'], other.id.value);
      expect((rig.cubit.state as AuthReady).club, _lyon);
    });

    test('a cache that cannot be cleared is unavailable, never served to '
        'the new account', () async {
      final other = rig.auth.seed(email: 'other@example.org', password: 'pw');
      rig.memberships.grant(other.id, _lyon);
      await rig.store.write('firestore_cache_owner', coach.id.value);
      rig.cache.clearFailure = const FormatException('disque');
      rig.auth.restoreSession('other@example.org');
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, const AuthIndisponible());
      expect(rig.scope.clubId, isNull);
      expect(reported, hasLength(1));
    });

    test(
      'signing out clears the cache, forgets its owner and reopens',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        await rig.cubit.start();
        await settle();

        final result = await rig.cubit.signOut();
        await settle();

        expect(result, SignOutResult.signedOut);
        expect(rig.cache.clears, 1);
        expect(rig.cache.reopens, 1);
        expect(rig.store.entries, isNot(contains('firestore_cache_owner')));
        expect(rig.cubit.state, const AuthSignedOut());
      },
    );

    test(
      'signing out with unsent writes is refused, nothing changes',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        await rig.cubit.start();
        await settle();
        rig.sends.track(Future<void>.delayed(const Duration(days: 1)));
        final before = rig.cubit.state;

        final result = await rig.cubit.signOut();
        await settle();

        expect(result, SignOutResult.unsentWrites);
        expect(rig.cubit.state, before);
        expect(rig.auth.current, isNotNull);
        expect(rig.cache.clears, 0);
      },
    );

    test(
      'confirmed, signing out loses the unsent writes with the cache',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        await rig.cubit.start();
        await settle();
        rig.sends.track(Future<void>.delayed(const Duration(days: 1)));

        final result = await rig.cubit.signOut(discardUnsent: true);
        await settle();

        expect(result, SignOutResult.signedOut);
        expect(rig.cache.clears, 1);
        expect(rig.cubit.state, const AuthSignedOut());
      },
    );

    test('a failed clearing still signs out, the owner stays recorded so the '
        'next account clears first', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      rig.cache.clearFailure = const FormatException('disque');
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final result = await rig.cubit.signOut();
      await settle();

      expect(result, SignOutResult.signedOut);
      // L'échec est traité : l'état le dit (message de l'écran de connexion).
      expect(rig.cubit.state, const AuthSignedOut(erasurePending: true));
      expect(rig.store.entries['firestore_cache_owner'], coach.id.value);
      expect(
        rig.store.entries[LocalDataGuard.erasurePendingKey],
        isNot(contains(coach.id.value)),
      );
      expect(await rig.local.erasurePending(), isTrue);
      expect(reported, hasLength(1));
    });

    group('an erasure that failed at sign-out', () {
      late List<FlutterErrorDetails> reported;

      setUp(() {
        reported = [];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
      });

      Future<void> signOutWithFailingCache() async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        await rig.cubit.start();
        await settle();
        rig.cache.clearFailure = const FormatException('disque');
        await rig.cubit.signOut();
        await settle();
      }

      test('retrying after the cause is gone clears the cache and drops the '
          'message', () async {
        await signOutWithFailingCache();
        rig.cache.clearFailure = null;

        await rig.cubit.retryErasure();

        expect(rig.cubit.state, const AuthSignedOut());
        expect(rig.cache.clears, 1);
        expect(rig.cache.reopens, 2);
        expect(await rig.local.erasurePending(), isFalse);
        expect(rig.store.entries, isNot(contains('firestore_cache_owner')));
      });

      test('retrying while it still fails keeps the message and the '
          'mark', () async {
        await signOutWithFailingCache();

        await rig.cubit.retryErasure();

        expect(rig.cubit.state, const AuthSignedOut(erasurePending: true));
        expect(await rig.local.erasurePending(), isTrue);
        expect(rig.cache.clears, 0);
        expect(reported, hasLength(2));
      });

      test('the next start retries before anything is read: cleared, no '
          'message', () async {
        await signOutWithFailingCache();
        final restarted = AuthRig();
        for (final entry in rig.store.entries.entries) {
          await restarted.store.write(entry.key, entry.value);
        }
        restarted.auth.seed(email: 'other@example.org', password: 'pw');

        await restarted.cubit.start();
        await settle();

        expect(restarted.cubit.state, const AuthSignedOut());
        expect(restarted.cache.clears, 1);
        expect(restarted.cache.reopens, 1);
        expect(await restarted.local.erasurePending(), isFalse);
        await restarted.cubit.close();
      });

      test('the next start still failing shows the message on the sign-in '
          'screen', () async {
        await signOutWithFailingCache();
        final restarted = AuthRig();
        for (final entry in rig.store.entries.entries) {
          await restarted.store.write(entry.key, entry.value);
        }
        restarted.cache.clearFailure = const FormatException('disque');

        await restarted.cubit.start();
        await settle();

        expect(
          restarted.cubit.state,
          const AuthSignedOut(erasurePending: true),
        );
        await restarted.cubit.close();
      });

      test('another account signing in while the erasure keeps failing is '
          'unavailable, with no club and no data served', () async {
        await signOutWithFailingCache();
        final restarted = AuthRig();
        for (final entry in rig.store.entries.entries) {
          await restarted.store.write(entry.key, entry.value);
        }
        final other = restarted.auth.seed(
          email: 'other@example.org',
          password: 'pw',
        );
        restarted.memberships.grant(other.id, _lyon);
        restarted.auth.restoreSession('other@example.org');
        restarted.cache.clearFailure = const FormatException('disque');

        await restarted.cubit.start();
        await settle();

        expect(restarted.cubit.state, const AuthIndisponible());
        expect(restarted.scope.clubId, isNull);
        await restarted.cubit.close();
      });

      test('the SAME account signing in again after the failure gets a '
          'cleared cache too', () async {
        await signOutWithFailingCache();
        rig.cache.clearFailure = null;

        await rig.auth.signIn(email: 'coach@example.org', password: 'pw');
        await settle();

        expect(rig.cache.clears, 1);
        expect(await rig.local.erasurePending(), isFalse);
        expect(rig.cubit.state, isA<AuthReady>());
      });
    });

    test('a session lost elsewhere keeps the cache: unsent writes may be in '
        'it, the same account finds them again', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();

      await rig.auth.signOut();
      await settle();
      // Plus longtemps que l'attente d'un effacement par un autre onglet.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(rig.cubit.state, const AuthSignedOut());
      expect(rig.cache.clears, 0);
      expect(rig.cache.reopens, 0);
      expect(rig.store.entries['firestore_cache_owner'], coach.id.value);
    });

    test(
      'a session lost because another tab signed out and cleared the '
      'cache reloads this one: its Firestore instance is terminated',
      () async {
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, _nice);
        await rig.cubit.start();
        await settle();
        // L'autre onglet a vidé le cache et oublié son propriétaire.
        await rig.store.remove('firestore_cache_owner');

        await rig.auth.signOut();
        await settle();

        expect(rig.cubit.state, const AuthSignedOut());
        expect(rig.cache.reopens, 1);
      },
    );

    test('the other tab signs out first and clears the cache a moment later: '
        'this one waits for it, then reloads', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();

      // La session se ferme AVANT l'effacement de l'autre onglet.
      await rig.auth.signOut();
      await settle();
      expect(rig.cache.reopens, 0);
      await rig.store.remove('firestore_cache_owner');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(rig.cache.reopens, 1);
    });

    test('signing in again while waiting cancels the reload', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      await rig.auth.signOut();
      await settle();

      await rig.auth.signIn(email: 'coach@example.org', password: 'pw');
      await settle();
      await rig.store.remove('firestore_cache_owner');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(rig.cache.reopens, 0);
    });

    test('signing out here reloads once even when another tab had already '
        'forgotten the owner: the sign-out is not "a session lost '
        'elsewhere"', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      await rig.store.remove('firestore_cache_owner');

      await rig.cubit.signOut();
      await settle();

      expect(rig.cache.reopens, 1);
    });

    test('signing out here reloads once, not twice', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();

      await rig.cubit.signOut();
      await settle();

      expect(rig.cache.reopens, 1);
    });
  });

  group('administrators, scope and invitations (FB3)', () {
    test('an administrator with no club reaches the administration', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.makeAdmin(coach.id);

      await rig.cubit.start();
      await settle();

      expect(
        rig.cubit.state,
        AuthNoClub(account: coach, choices: const [], isAdmin: true),
      );
      expect(rig.scope.isAdmin, isTrue);
      expect(rig.scope.clubId, isNull);
    });

    test(
      'an administrator acting in a club is ready, flagged as such',
      () async {
        const admin = ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.admin,
        );
        rig.auth.restoreSession('coach@example.org');
        rig.memberships
          ..makeAdmin(coach.id)
          ..grant(coach.id, admin);

        await rig.cubit.start();
        await settle();

        expect(
          rig.cubit.state,
          AuthReady(
            account: coach,
            club: admin,
            choices: const [admin],
            isAdmin: true,
          ),
        );
        expect(rig.scope.role, Role.admin);
        expect(rig.scope.isAdmin, isTrue);
      },
    );

    test('a plain account is not an administrator', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);

      await rig.cubit.start();
      await settle();

      expect(rig.scope.isAdmin, isFalse);
      expect((rig.cubit.state as AuthReady).isAdmin, isFalse);
    });

    test(
      'the scope carries the groups and the students of the member',
      () async {
        const family = ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.guardian,
          groupIds: [GroupId('g1')],
          studentIds: [StudentId('s1'), StudentId('s2')],
        );
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, family);

        await rig.cubit.start();
        await settle();

        expect(rig.scope.role, Role.guardian);
        expect(rig.scope.groupIds, [const GroupId('g1')]);
        expect(rig.scope.studentIds, [
          const StudentId('s1'),
          const StudentId('s2'),
        ]);
        expect(await rig.memory.read(coach.id), family);
      },
    );

    test(
      'the groups and students of a club are forgotten when it is left',
      () async {
        const family = ClubMembership(
          clubId: ClubId('nice'),
          clubName: 'Club Nice',
          role: Role.student,
          studentIds: [StudentId('s1')],
        );
        rig.auth.restoreSession('coach@example.org');
        rig.memberships.grant(coach.id, family);
        await rig.cubit.start();
        await settle();

        await rig.cubit.signOut();

        expect(rig.scope.studentIds, isEmpty);
        expect(rig.scope.groupIds, isEmpty);
        expect(rig.scope.isAdmin, isFalse);
      },
    );

    test(
      'a code kept at sign-up is offered to an account with no club',
      () async {
        rig.auth.restoreSession('coach@example.org');
        final code = InvitationCode.tryParse('ABCDEFGHJKMN')!;
        await rig.pending.hold(coach.id, code);

        await rig.cubit.start();
        await settle();

        expect(
          rig.cubit.state,
          AuthNoClub(
            account: coach,
            choices: const [],
            pendingInvitation: code,
          ),
        );
      },
    );

    test('a kept code does not hold back an account that has a club', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.pending.hold(
        coach.id,
        InvitationCode.tryParse('ABCDEFGHJKMN')!,
      );

      await rig.cubit.start();
      await settle();

      expect(rig.cubit.state, isA<AuthReady>());
    });

    test('refresh offers the club that the invitation just created', () async {
      rig.auth.restoreSession('coach@example.org');
      await rig.cubit.start();
      await settle();
      expect((rig.cubit.state as AuthNoClub).choices, isEmpty);

      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.refresh();

      expect(rig.cubit.state, isA<AuthReady>());
      expect(rig.scope.clubId, _nice.clubId);
    });

    test('signing out forgets the invitations sent from the device', () async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _nice);
      await rig.cubit.start();
      await settle();
      await rig.issued.add(
        coach.id,
        _nice.clubId,
        IssuedInvitation(
          code: InvitationCode.tryParse('ABCDEFGHJKMN')!,
          role: Role.teacher,
          createdAt: DateTime(2026, 10, 12),
          expiresAt: DateTime(2026, 10, 14),
        ),
      );

      await rig.cubit.signOut();

      expect(await rig.issued.read(coach.id, _nice.clubId), isEmpty);
    });

    test('choosing a club keeps the administrator flag', () async {
      const other = ClubMembership(
        clubId: ClubId('lyon'),
        clubName: 'Club Lyon',
        role: Role.admin,
      );
      rig.auth.restoreSession('coach@example.org');
      rig.memberships
        ..makeAdmin(coach.id)
        ..grant(coach.id, _nice)
        ..grant(coach.id, other);
      await rig.cubit.start();
      await settle();
      expect(rig.cubit.state, isA<AuthNoClub>());

      expect(await rig.cubit.chooseClub(other), isTrue);

      expect((rig.cubit.state as AuthReady).isAdmin, isTrue);
      expect(rig.scope.role, Role.admin);
    });
  });

  group('account deletion (FB8 partie B)', () {
    Future<void> openTeacherClub() async {
      rig.auth.restoreSession('coach@example.org');
      rig.memberships.grant(coach.id, _lyon);
      await rig.cubit.start();
      await settle();
      expect(rig.cubit.state, isA<AuthReady>());
    }

    test('a deleted account is signed out and forgotten on the device, like '
        'a sign-out', () async {
      await openTeacherClub();
      await rig.pending.hold(coach.id, InvitationCode.tryParse('AAAAAAAAAA')!);
      final steps = <AccountDeletionStep>[];

      final result = await rig.cubit.deleteAccount('pw', onProgress: steps.add);
      await settle();

      expect(result, const AccountDeletionResult.deleted());
      expect(rig.cubit.state, const AuthSignedOut());
      expect(rig.auth.accountOf('coach@example.org'), isNull);
      expect(rig.members.removed, [(_lyon.clubId, coach.id)]);
      expect(rig.scope.id, isNull);
      expect(await rig.memory.read(coach.id), isNull);
      expect(await rig.pending.read(coach.id), isNull);
      expect(
        rig.store.entries.keys.where((key) => key.contains(coach.id.value)),
        isEmpty,
      );
      expect(rig.cache.clears, 1);
      expect(rig.cache.reopens, 1);
      expect(steps.last, const AccountDeletionStep.removingAccount());
    });

    test(
      'a refusal changes nothing: still in the club, account kept',
      () async {
        await openTeacherClub();
        final before = rig.cubit.state;

        final result = await rig.cubit.deleteAccount('wrong');
        await settle();

        expect(
          result,
          const AccountDeletionResult.failed(
            AccountDeletionError.wrongPassword,
          ),
        );
        expect(rig.cubit.state, before);
        expect(rig.auth.current, isNotNull);
        expect(rig.cache.clears, 0);
      },
    );

    test('stopped after the purge, the session is read again: no club left, '
        'and the account can still finish its deletion', () async {
      await openTeacherClub();
      rig.auth.nextDeletionFailure = AuthFailureCode.network;

      final first = await rig.cubit.deleteAccount('pw');
      await settle();

      expect(
        first,
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      );
      expect(rig.cubit.state, isA<AuthNoClub>());
      expect((rig.cubit.state as AuthNoClub).choices, isEmpty);
      expect(rig.cache.clears, 0);

      final second = await rig.cubit.deleteAccount('pw');
      await settle();

      expect(second, const AccountDeletionResult.deleted());
      expect(rig.cubit.state, const AuthSignedOut());
    });

    test('a cache that cannot be cleared still ends signed out, with the '
        'erasure pending', () async {
      await openTeacherClub();
      rig.cache.clearFailure = const FormatException('disque');
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final result = await rig.cubit.deleteAccount('pw');
      await settle();

      expect(result, const AccountDeletionResult.deleted());
      expect(rig.cubit.state, const AuthSignedOut(erasurePending: true));
      expect(reported, hasLength(1));
    });

    test('without a session there is nothing to delete', () async {
      await rig.cubit.start();
      await settle();

      expect(
        await rig.cubit.deleteAccount('pw'),
        const AccountDeletionResult.failed(AccountDeletionError.unavailable),
      );
    });
  });
}
