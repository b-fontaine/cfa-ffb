import 'dart:async';

import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/domain/delete_own_account.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/operations/in_memory_own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_send_status.dart';
import '../../../../support/in_memory_memberships_source.dart';

/// Les `members` des clubs, et ce que la suppression leur demande (ordre des
/// appels compris).
class _Members implements MemberRepository {
  _Members(this.journal);

  final List<String> journal;
  final Map<ClubId, List<Member>> byClub = {};

  /// Le retrait échoue avec cet échec.
  ServiceFailure? removeFails;

  /// Le retrait n'aboutit jamais (hors ligne : l'accusé du serveur n'arrive
  /// pas).
  bool removeHangs = false;

  @override
  Future<List<Member>> membersOf(ClubId club) async {
    journal.add('membersOf ${club.value}');
    return byClub[club] ?? const [];
  }

  @override
  Future<void> remove(ClubId club, UserId user) {
    journal.add('remove ${club.value} ${user.value}');
    if (removeHangs) return Completer<void>().future;
    return _removeNow(club, user);
  }

  Future<void> _removeNow(ClubId club, UserId user) async {
    final failure = removeFails;
    if (failure != null) throw failure;
    byClub[club]?.removeWhere((member) => member.uid == user);
  }
}

/// Les invitations du serveur (par code) ; la liste au serveur et la
/// révocation sont journalisées.
class _Invitations implements InvitationRepository {
  _Invitations(this.journal);

  final List<String> journal;
  final Map<String, Invitation> stored = {};

  /// Les codes déjà utilisés (consommés par un invité).
  final Set<String> used = {};

  /// La liste au serveur échoue avec cet échec.
  ServiceFailure? listFails;

  @override
  Future<List<InvitationCode>> unusedIssuedBy(UserId user, ClubId club) async {
    journal.add('invitations ${club.value}');
    final failure = listFails;
    if (failure != null) throw failure;
    return [
      for (final invitation in stored.values)
        if (invitation.clubId == club &&
            invitation.createdBy == user &&
            !used.contains(invitation.code.value))
          invitation.code,
    ];
  }

  @override
  Future<void> create(Invitation invitation) async =>
      stored[invitation.code.value] = invitation;

  @override
  Future<Invitation?> find(InvitationCode code) async => stored[code.value];

  @override
  Future<void> revoke(InvitationCode code) async {
    journal.add('revoke ${code.value}');
    stored.remove(code.value);
  }

  @override
  Future<void> accept({
    required InvitationCode code,
    required UserId user,
    required String displayName,
  }) => throw UnimplementedError();
}

/// Le magasin des marqueurs du compte, journalisé.
class _Markers implements OwnMarkerStore {
  _Markers(this._inner, this.journal);

  final InMemoryOwnMarkerStore _inner;
  final List<String> journal;

  /// La liste échoue avec cet échec (au serveur : hors ligne, `unavailable`
  /// plutôt qu'une liste vide venue du cache).
  Failure? listFails;

  @override
  Future<List<OwnMarker>> list(ClubId club, MarkerKind kind) async {
    journal.add('list ${kind.name} ${club.value}');
    final failure = listFails;
    if (failure != null) throw failure;
    return await _inner.list(club, kind);
  }

  @override
  Future<void> delete(ClubId club, List<OwnMarker> markers) {
    journal.add('markers ${club.value} ${markers.length}');
    return _inner.delete(club, markers);
  }
}

const _me = UserId('u-me');
const _nice = ClubId('nice');
const _lyon = ClubId('lyon');
final _now = DateTime(2026, 10, 12, 9, 30);

Member _member(String uid, Role role) =>
    Member(uid: UserId(uid), role: role, displayName: uid);

void main() {
  late List<String> journal;
  late InMemoryAuthRepository auth;
  late InMemoryMembershipsSource memberships;
  late _Members members;
  late InMemoryOwnMarkerStore markers;
  late _Markers journaledMarkers;
  late _Invitations invitations;
  late FakeSendStatus sends;
  late DeleteOwnAccount deleteOwnAccount;
  late List<AccountDeletionStep> steps;

  setUp(() {
    journal = [];
    auth = InMemoryAuthRepository()
      ..seed(email: 'me@example.org', password: 'right-password', uid: 'u-me')
      ..restoreSession('me@example.org');
    memberships = InMemoryMembershipsSource();
    members = _Members(journal);
    final scope = SessionScope()..signIn(_me);
    markers = InMemoryOwnMarkerStore(scope);
    invitations = _Invitations(journal);
    sends = FakeSendStatus();
    journaledMarkers = _Markers(markers, journal);
    deleteOwnAccount = DeleteOwnAccount.withTimeout(
      auth,
      memberships,
      members,
      RemoveOwnMarkers(journaledMarkers),
      invitations,
      sends,
      ackTimeout: const Duration(milliseconds: 50),
    );
    steps = [];
  });

  void joins(ClubId club, String name, Role role) {
    memberships.grant(
      _me,
      ClubMembership(clubId: club, clubName: name, role: role),
    );
    (members.byClub[club] ??= []).add(_member(_me.value, role));
  }

  Future<AccountDeletionResult> delete([String password = 'right-password']) =>
      deleteOwnAccount(user: _me, password: password, onProgress: steps.add);

  /// Une invitation émise par [by] (depuis n'importe quel appareil : le
  /// serveur seul la connaît).
  Future<void> issue(
    ClubId club,
    String code, {
    bool expired = false,
    UserId by = _me,
  }) async {
    final created = expired
        ? _now.subtract(const Duration(days: 8))
        : _now.subtract(const Duration(hours: 1));
    await invitations.create(
      Invitation(
        code: InvitationCode.tryParse(code)!,
        clubId: club,
        role: Role.teacher,
        createdBy: by,
        createdAt: created,
        expiresAt: created.add(const Duration(days: 2)),
      ),
    );
  }

  group('the safe order', () {
    test('a teacher leaves each club (invitations, markers, member last), '
        'then the account goes', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      joins(_lyon, 'Club Lyon', Role.guardian);
      markers
        ..seed(_nice, MarkerKind.import, 'k1', 'u-me')
        ..seed(_nice, MarkerKind.import, 'k2', 'u-other');
      await issue(_nice, 'AAAAAAAAAA');

      final result = await delete();

      expect(result, const AccountDeletionResult.deleted());
      expect(journal, [
        'invitations nice',
        'revoke AAAAAAAAAA',
        'list import nice',
        'markers nice 1',
        'remove nice u-me',
        'remove lyon u-me',
      ]);
      expect(markers.contains(_nice, MarkerKind.import, 'k2', 'u-other'), true);
      expect(auth.accountOf('me@example.org'), isNull);
      expect(steps, const [
        AccountDeletionStep.checkingIdentity(),
        AccountDeletionStep.leavingClub(
          clubName: 'Club Nice',
          index: 1,
          count: 2,
        ),
        AccountDeletionStep.leavingClub(
          clubName: 'Club Lyon',
          index: 2,
          count: 2,
        ),
        AccountDeletionStep.removingAccount(),
      ]);
    });

    test(
      'every unused invitation I created in the club is revoked, from '
      "any device and even expired; used ones and a colleague's stay",
      () async {
        joins(_nice, 'Club Nice', Role.teacher);
        await issue(_nice, 'AAAAAAAAAA');
        await issue(_nice, 'BBBBBBBBBB', expired: true);
        await issue(_nice, 'CCCCCCCCCC');
        invitations.used.add('CCCCCCCCCC');
        await issue(_nice, 'DDDDDDDDDD', by: const UserId('u-colleague'));
        await issue(_lyon, 'EEEEEEEEEE');

        await delete();

        expect(journal.where((line) => line.startsWith('revoke')), [
          'revoke AAAAAAAAAA',
          'revoke BBBBBBBBBB',
        ]);
        expect(invitations.stored.keys, {
          'CCCCCCCCCC',
          'DDDDDDDDDD',
          'EEEEEEEEEE',
        });
      },
    );

    test('a parent or a student invites nobody: no invitation is listed, '
        'no marker either', () async {
      joins(_nice, 'Club Nice', Role.guardian);
      joins(_lyon, 'Club Lyon', Role.student);

      expect(await delete(), const AccountDeletionResult.deleted());
      expect(journal, ['remove nice u-me', 'remove lyon u-me']);
    });

    test(
      'a director demoted to teacher: their old operation markers cannot '
      'be listed by a teacher (rules) and are left to the 90-day net',
      () async {
        joins(_nice, 'Club Nice', Role.teacher);
        markers
          ..seed(_nice, MarkerKind.import, 'k1', 'u-me')
          ..seed(_nice, MarkerKind.operation, 'k2', 'u-me');

        expect(await delete(), const AccountDeletionResult.deleted());
        expect(journal, isNot(contains('list operation nice')));
        expect(
          markers.contains(_nice, MarkerKind.import, 'k1', 'u-me'),
          isFalse,
        );
        expect(
          markers.contains(_nice, MarkerKind.operation, 'k2', 'u-me'),
          true,
        );
        expect(auth.accountOf('me@example.org'), isNull);
      },
    );

    test('a club deleted by the administrator (or without a readable name) '
        'still has its member, markers and invitations removed before the '
        'account goes', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      memberships.orphan(_me, _lyon, Role.director);
      (members.byClub[_lyon] ??= []).add(_member(_me.value, Role.director));
      markers.seed(_lyon, MarkerKind.operation, 'k3', 'u-me');
      await issue(_lyon, 'FFFFFFFFFF');

      final result = await delete();

      expect(result, const AccountDeletionResult.deleted());
      expect(journal, [
        'invitations nice',
        'list import nice',
        'remove nice u-me',
        'invitations lyon',
        'revoke FFFFFFFFFF',
        'list import lyon',
        'list operation lyon',
        'markers lyon 1',
        'remove lyon u-me',
      ]);
      expect(members.byClub[_lyon], isEmpty);
      expect(
        markers.contains(_lyon, MarkerKind.operation, 'k3', 'u-me'),
        false,
      );
      expect(steps, const [
        AccountDeletionStep.checkingIdentity(),
        AccountDeletionStep.leavingClub(
          clubName: 'Club Nice',
          index: 1,
          count: 2,
        ),
        AccountDeletionStep.leavingClub(index: 2, count: 2),
        AccountDeletionStep.removingAccount(),
      ]);
    });

    test('an account without any club goes straight to the deletion', () async {
      final result = await delete();

      expect(result, const AccountDeletionResult.deleted());
      expect(journal, isEmpty);
      expect(auth.accountOf('me@example.org'), isNull);
    });
  });

  group('refusals, before any write', () {
    test(
      'changes not sent yet: refused without even asking the service',
      () async {
        joins(_nice, 'Club Nice', Role.teacher);
        sends.unsent = true;

        final result = await delete();

        expect(
          result,
          const AccountDeletionResult.refused(
            AccountDeletionRefusal.unsentWrites,
          ),
        );
        expect(steps, isEmpty);
        expect(journal, isEmpty);
        expect(auth.accountOf('me@example.org'), isNotNull);
      },
    );

    test('a wrong password deletes nothing', () async {
      joins(_nice, 'Club Nice', Role.teacher);

      final result = await delete('wrong-password');

      expect(
        result,
        const AccountDeletionResult.failed(AccountDeletionError.wrongPassword),
      );
      expect(journal, isEmpty);
    });

    test('an administrator is refused (console only)', () async {
      memberships.makeAdmin(_me);
      joins(_nice, 'Club Nice', Role.director);

      final result = await delete();

      expect(
        result,
        const AccountDeletionResult.refused(
          AccountDeletionRefusal.administrator,
        ),
      );
      expect(journal, isEmpty);
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test(
      'the last director of a club is refused, with the club named',
      () async {
        joins(_lyon, 'Club Lyon', Role.teacher);
        joins(_nice, 'Club Nice', Role.director);
        members.byClub[_nice]!.add(_member('u-teacher', Role.teacher));

        final result = await delete();

        expect(
          result,
          const AccountDeletionResult.refused(
            AccountDeletionRefusal.lastDirector,
            clubName: 'Club Nice',
          ),
        );
        expect(journal, ['membersOf nice']);
        expect(auth.accountOf('me@example.org'), isNotNull);
      },
    );

    test('a director with another director in the club goes through', () async {
      joins(_nice, 'Club Nice', Role.director);
      members.byClub[_nice]!.add(_member('u-successor', Role.director));

      final result = await delete();

      expect(result, const AccountDeletionResult.deleted());
      expect(members.byClub[_nice]!.map((m) => m.uid), [
        const UserId('u-successor'),
      ]);
    });

    test('offline: the password check fails and nothing is deleted', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      auth.offline = true;

      final result = await delete();

      expect(
        result,
        const AccountDeletionResult.failed(AccountDeletionError.network),
      );
      expect(journal, isEmpty);
    });

    test('unreadable clubs: nothing is deleted', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      memberships.unavailable = true;

      expect(
        await delete(),
        const AccountDeletionResult.failed(AccountDeletionError.network),
      );
      memberships
        ..unavailable = false
        ..denied = true;
      expect(
        await delete(),
        const AccountDeletionResult.failed(AccountDeletionError.unavailable),
      );
      expect(journal, isEmpty);
    });

    test('too many attempts is reported as such', () async {
      auth.offline = false;
      final throttled = _ThrottledAuth();
      deleteOwnAccount = DeleteOwnAccount(
        throttled,
        memberships,
        members,
        RemoveOwnMarkers(markers),
        invitations,
        sends,
      );

      expect(
        await delete(),
        const AccountDeletionResult.failed(
          AccountDeletionError.tooManyRequests,
        ),
      );
    });
  });

  group('the server, never the cache, says what is left', () {
    test('the members unreadable at the server: nothing is deleted', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      memberships.serverUnavailable = true;

      expect(
        await delete(),
        const AccountDeletionResult.failed(AccountDeletionError.network),
      );
      expect(journal, isNot(contains('remove nice u-me')));
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test('my markers unreadable at the server (offline): the member stays, '
        'the account is never deleted with markers left behind', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      markers.seed(_nice, MarkerKind.import, 'k1', 'u-me');
      journaledMarkers.listFails = const ServiceFailure(
        ServiceFailureCode.unavailable,
      );

      final result = await delete();

      expect(
        result,
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      );
      expect(journal, isNot(contains('remove nice u-me')));
      expect(markers.contains(_nice, MarkerKind.import, 'k1', 'u-me'), isTrue);
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test('my invitations unreadable at the server: the purge stops before '
        'the markers and the member', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      invitations.listFails = const ServiceFailure(
        ServiceFailureCode.unavailable,
      );

      expect(
        await delete(),
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      );
      expect(journal, ['invitations nice']);
      expect(auth.accountOf('me@example.org'), isNotNull);
    });
  });

  group('any failure ends in an outcome, never a stuck screen', () {
    test('the check of unsent writes failing: nothing is deleted', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      final failing = _FailingSends();
      deleteOwnAccount = DeleteOwnAccount.withTimeout(
        auth,
        memberships,
        members,
        RemoveOwnMarkers(journaledMarkers),
        invitations,
        failing,
        ackTimeout: const Duration(milliseconds: 50),
      );

      expect(
        await delete(),
        const AccountDeletionResult.failed(AccountDeletionError.unavailable),
      );
      expect(journal, isEmpty);
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test('an unexpected failure while leaving a club stops part-way, and the '
        'account stays', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      journaledMarkers.listFails = const InvariantViolation(
        InvariantCode.invalidRange,
      );

      expect(
        await delete(),
        const AccountDeletionResult.failed(
          AccountDeletionError.unavailable,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      );
      expect(journal, isNot(contains('remove nice u-me')));
      expect(auth.accountOf('me@example.org'), isNotNull);
    });
  });

  group('interruptions and resumption', () {
    test('a member removal that never gets the server ack stops the purge '
        'part-way, and the account stays', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      members.removeHangs = true;

      final result = await delete();

      expect(
        result,
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      );
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test('a refused member removal stops the purge part-way', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      members.removeFails = const ServiceFailure(ServiceFailureCode.denied);

      expect(
        await delete(),
        const AccountDeletionResult.failed(
          AccountDeletionError.unavailable,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        ),
      );
      expect(auth.accountOf('me@example.org'), isNotNull);
    });

    test('the account deletion failing after the purge says the club data '
        'is gone; replaying finishes without touching any club', () async {
      joins(_nice, 'Club Nice', Role.teacher);
      auth.nextDeletionFailure = AuthFailureCode.network;

      final first = await delete();

      expect(
        first,
        const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataRemoved,
        ),
      );
      expect(auth.accountOf('me@example.org'), isNotNull);
      // La session relue ne voit plus ce club : rien à refaire là.
      memberships.revokeAll(_me);
      journal.clear();

      expect(await delete(), const AccountDeletionResult.deleted());
      expect(journal, isEmpty);
    });

    test(
      'an expired password check at the very end asks for it again',
      () async {
        joins(_nice, 'Club Nice', Role.teacher);
        auth.nextDeletionFailure = AuthFailureCode.recentLoginRequired;

        expect(
          await delete(),
          const AccountDeletionResult.failed(
            AccountDeletionError.passwordCheckExpired,
            progress: AccountDeletionProgress.clubDataRemoved,
          ),
        );
      },
    );

    test(
      'without any club, a failing account deletion deleted nothing',
      () async {
        auth.nextDeletionFailure = AuthFailureCode.unavailable;

        expect(
          await delete(),
          const AccountDeletionResult.failed(AccountDeletionError.unavailable),
        );
      },
    );
  });
}

/// Le service refuse toute tentative : trop de tentatives.
class _ThrottledAuth extends InMemoryAuthRepository {
  @override
  Future<void> reauthenticate(String password) async =>
      throw const AuthFailure(AuthFailureCode.tooManyRequests);

  @override
  Stream<Account?> watchAccount() => const Stream.empty();
}

/// Le suivi des envois dont la lecture échoue (stockage local illisible).
class _FailingSends extends FakeSendStatus {
  @override
  Future<bool> hasUnsentWrites() async =>
      throw const ServiceFailure(ServiceFailureCode.other, 'stockage');
}
