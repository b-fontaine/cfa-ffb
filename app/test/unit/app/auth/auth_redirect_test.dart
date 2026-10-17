import 'package:billard_cfa/app/auth/auth_redirect.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = Account(
  id: UserId('u1'),
  email: 'coach@example.org',
  emailVerified: true,
);
const _club = ClubMembership(
  clubId: ClubId('nice'),
  clubName: 'Club Nice',
  role: Role.director,
);
const _ready = AuthReady(account: _account, club: _club, choices: [_club]);
const _noClub = AuthNoClub(account: _account, choices: []);

String? _go(AuthState state, String location) =>
    authRedirect(state, Uri.parse(location));

void main() {
  group('unknown', () {
    test('every address goes to the splash screen, keeping where it was', () {
      expect(
        _go(const AuthUnknown(), '/students/s1'),
        '/splash?from=%2Fstudents%2Fs1',
      );
    });

    test('the home address is not worth remembering', () {
      expect(_go(const AuthUnknown(), '/'), '/splash');
    });

    test('the splash screen stays', () {
      expect(_go(const AuthUnknown(), '/splash?from=%2Fbackup'), isNull);
    });

    test('another session screen hands its own origin to the splash', () {
      expect(
        _go(const AuthUnknown(), '/sign-in?from=%2Fbackup'),
        '/splash?from=%2Fbackup',
      );
    });
  });

  group('signed out', () {
    test('a protected address goes to the sign-in screen, with a way back', () {
      expect(
        _go(const AuthSignedOut(), '/backup?x=1'),
        '/sign-in?from=%2Fbackup%3Fx%3D1',
      );
    });

    test('the three access screens stay reachable', () {
      for (final path in ['/sign-in', '/forgot-password', '/register']) {
        expect(_go(const AuthSignedOut(), path), isNull, reason: path);
      }
    });

    test('the club and unavailable screens are not reachable', () {
      expect(_go(const AuthSignedOut(), '/select-club'), '/sign-in');
      expect(_go(const AuthSignedOut(), '/unavailable'), '/sign-in');
    });

    test('no address is open without an account, however deep', () {
      for (final path in [
        '/students',
        '/exercises/puissance/1',
        '/catalogue/posture-1/guide',
        '/more/club',
        '/nowhere',
      ]) {
        expect(
          _go(const AuthSignedOut(), path),
          startsWith('/sign-in'),
          reason: path,
        );
      }
    });
  });

  group('no club', () {
    test('everything goes to the club choice', () {
      expect(_go(_noClub, '/students'), '/select-club?from=%2Fstudents');
      expect(_go(_noClub, '/sign-in'), '/select-club');
    });

    test('the club choice stays', () {
      expect(_go(_noClub, '/select-club'), isNull);
    });
  });

  group('unavailable', () {
    test('everything goes to the dedicated screen', () {
      expect(const AuthIndisponible().runtimeType, AuthIndisponible);
      expect(_go(const AuthIndisponible(), '/'), '/unavailable');
      expect(_go(const AuthIndisponible(), '/unavailable'), isNull);
    });
  });

  group('ready', () {
    test('protected addresses are open', () {
      expect(_go(_ready, '/students'), isNull);
      expect(_go(_ready, '/'), isNull);
      expect(_go(_ready, '/more/club'), isNull);
    });

    test('a session screen leads back to the requested address', () {
      expect(_go(_ready, '/sign-in?from=%2Fbackup'), '/backup');
      expect(
        _go(_ready, '/splash?from=%2Fstudents%2Fs1%3Fa%3D1'),
        '/students/s1?a=1',
      );
    });

    test('a session screen without an origin leads home', () {
      expect(_go(_ready, '/sign-in'), '/');
      expect(_go(_ready, '/select-club'), '/');
      expect(_go(_ready, '/unavailable'), '/');
    });

    test('never follows an outside or looping address', () {
      for (final from in [
        'https://evil.example/',
        '//evil.example/x',
        'javascript:alert(1)',
        '/sign-in',
        '/splash?from=%2Fbackup',
        'backup',
        '',
      ]) {
        expect(
          _go(_ready, '/sign-in?from=${Uri.encodeComponent(from)}'),
          '/',
          reason: from,
        );
      }
    });
  });

  group('safeReturnAddress', () {
    test('keeps an inner address with its query', () {
      expect(safeReturnAddress('/backup?a=1'), '/backup?a=1');
    });

    test('drops nothing, null, the home address and session screens', () {
      expect(safeReturnAddress(null), isNull);
      expect(safeReturnAddress('/'), isNull);
      expect(safeReturnAddress('/register'), isNull);
    });
  });

  group('invitation links', () {
    test(
      'signed out, /join/<code> opens the sign-up with the code filled in',
      () {
        expect(
          _go(const AuthSignedOut(), '/join/ABCDEFGHJKMN'),
          '/register?code=ABCDEFGHJKMN',
        );
      },
    );

    test('signed out, /join without a usable code leads to the sign-in, as at a cold start', () {
      for (final path in ['/join', '/join/a/b', '/join/abc']) {
        expect(_go(const AuthSignedOut(), path), '/sign-in', reason: path);
        final first = _go(const AuthUnknown(), path)!;
        expect(
          _go(const AuthSignedOut(), first),
          '/sign-in',
          reason: 'cold $path',
        );
      }
    });

    test('signed out, a look-alike address is not a join link', () {
      expect(
        _go(const AuthSignedOut(), '/joined/ABCDEFGHJKMN'),
        startsWith('/sign-in'),
      );
    });

    test('isJoinPath tells /join and /join/<code> from the rest', () {
      expect(isJoinPath('/join'), isTrue);
      expect(isJoinPath('/join/ABC'), isTrue);
      expect(isJoinPath('/joined'), isFalse);
      expect(isJoinPath('/students/join'), isFalse);
    });
  });

  group('invitation links at a cold start', () {
    // L'état initial est toujours `unknown` : le lien doit survivre à
    // l'écran de démarrage, sans passer par `from`.
    test('unknown keeps the code of the link on the splash screen', () {
      expect(
        _go(const AuthUnknown(), '/join/ABCDEFGHJKMN'),
        '/splash?code=ABCDEFGHJKMN',
      );
    });

    test('the splash screen holding a code stays', () {
      expect(_go(const AuthUnknown(), '/splash?code=ABCDEFGHJKMN'), isNull);
    });

    test('unknown then signed out: the sign-up opens with the code', () {
      final first = _go(const AuthUnknown(), '/join/ABCDEFGHJKMN')!;
      expect(_go(const AuthSignedOut(), first), '/register?code=ABCDEFGHJKMN');
    });

    test('unknown then no club: the invitation is offered', () {
      final first = _go(const AuthUnknown(), '/join/ABCDEFGHJKMN')!;
      expect(_go(_noClub, first), '/join/ABCDEFGHJKMN');
    });

    test('unknown then ready: the invitation is offered too', () {
      final first = _go(const AuthUnknown(), '/join/ABCDEFGHJKMN')!;
      expect(_go(_ready, first), '/join/ABCDEFGHJKMN');
    });

    test('a register address with a code survives the splash screen', () {
      final first = _go(const AuthUnknown(), '/register?code=ABCDEFGHJKMN')!;
      expect(first, '/splash?code=ABCDEFGHJKMN');
      expect(_go(const AuthSignedOut(), first), '/register?code=ABCDEFGHJKMN');
    });

    test('a malformed code is dropped, never copied to the address', () {
      expect(_go(const AuthUnknown(), '/join/abc'), '/splash');
      expect(_go(const AuthUnknown(), '/join'), '/splash');
      expect(_go(const AuthSignedOut(), '/splash?code=abc'), '/sign-in');
    });

    test('no join address is ever kept as a return address', () {
      expect(safeReturnAddress('/join/ABCDEFGHJKMN'), isNull);
      expect(safeReturnAddress('/join'), isNull);
      expect(safeReturnAddress('/joined'), '/joined');
    });
  });

  group('no club: joining and administration', () {
    test('the join screens stay reachable without a club', () {
      expect(_go(_noClub, '/join'), isNull);
      expect(_go(_noClub, '/join/ABCDEFGHJKMN'), isNull);
    });

    test(
      'a kept invitation code sends a club-less account to /join/<code>',
      () {
        final pending = AuthNoClub(
          account: _account,
          choices: const [],
          pendingInvitation: InvitationCode.tryParse('ABCDEFGHJKMN'),
        );
        for (final path in ['/', '/students', '/select-club', '/sign-in']) {
          expect(_go(pending, path), '/join/ABCDEFGHJKMN', reason: path);
        }
        expect(_go(pending, '/join/OTHEROTHERXY'), isNull);
      },
    );

    test('with several clubs to choose from, the choice comes first', () {
      final pending = AuthNoClub(
        account: _account,
        choices: const [_club],
        pendingInvitation: InvitationCode.tryParse('ABCDEFGHJKMN'),
      );
      expect(_go(pending, '/'), '/select-club');
    });

    test('an administrator reaches the administration without a club', () {
      const admin = AuthNoClub(account: _account, choices: [], isAdmin: true);
      expect(_go(admin, '/administration'), isNull);
      expect(_go(admin, '/students'), '/select-club?from=%2Fstudents');
    });

    test('anybody else is sent back to the club choice', () {
      expect(
        _go(_noClub, '/administration'),
        '/select-club?from=%2Fadministration',
      );
    });
  });

  group('role guard', () {
    AuthReady as(
      Role role, {
      bool admin = false,
      List<String> students = const [],
    }) => AuthReady(
      account: _account,
      club: ClubMembership(
        clubId: const ClubId('nice'),
        clubName: 'Club Nice',
        role: role,
        studentIds: [for (final s in students) StudentId(s)],
      ),
      choices: const [],
      isAdmin: admin,
    );

    void expectAll(AuthReady state, Map<String, String?> expected) {
      expected.forEach((path, target) {
        expect(
          authRedirect(state, Uri.parse(path)),
          target,
          reason: '${state.club.role.name} $path',
        );
      });
    }

    test(
      'a teacher animates but neither sets up the club nor closes a season',
      () {
        expectAll(as(Role.teacher), {
          '/': null,
          '/students': null,
          '/planner': null,
          '/backup': null,
          '/seasons': null,
          '/club': null,
          '/club/invite': null,
          '/more': null,
          '/more/club': null,
          '/settings': '/',
          '/seasons/s1/close': '/',
          '/administration': '/',
          '/my-children': '/',
          '/join/ABCDEFGHJKMN': null,
        });
      },
    );

    test('a director also sets up the club and closes a season', () {
      expectAll(as(Role.director), {
        '/settings': null,
        '/seasons/s1/close': null,
        '/seasons/s1': null,
        '/club': null,
        '/administration': '/',
        '/my-children': '/',
      });
    });

    test(
      'an administrator reaches the administration, whatever the club role',
      () {
        expectAll(as(Role.director, admin: true), {'/administration': null});
        expectAll(as(Role.admin, admin: true), {
          '/administration': null,
          '/settings': null,
          '/seasons/s1/close': null,
          '/club': null,
        });
      },
    );

    for (final role in [Role.student, Role.guardian]) {
      test(
        '${role.name}: own progress only, everything else goes back to it',
        () {
          expectAll(as(role, students: ['s1']), {
            '/my-children': null,
            '/more': null,
            '/more/club': null,
            '/students/s1/show': null,
            '/join/ABCDEFGHJKMN': null,
            '/': '/my-children',
            '/students': '/my-children',
            '/students/s1': '/my-children',
            '/students/s1/edit': '/my-children',
            '/students/s2/show': '/my-children',
            '/students/s1/show/extra': '/my-children',
            '/planner': '/my-children',
            '/backup': '/my-children',
            '/settings': '/my-children',
            '/seasons': '/my-children',
            '/club': '/my-children',
            '/club/invite': '/my-children',
            '/catalogue/posture-1/guide': '/my-children',
            '/administration': '/',
          });
        },
      );
    }

    test('a parent of two children opens both, and no other', () {
      expectAll(as(Role.guardian, students: ['s1', 's2']), {
        '/students/s1/show': null,
        '/students/s2/show': null,
        '/students/s3/show': '/my-children',
      });
    });

    test('a student with no linked student opens none', () {
      expectAll(as(Role.student), {'/students/s1/show': '/my-children'});
    });

    test(
      'an administrator who is also a parent still reaches the administration',
      () {
        expectAll(as(Role.guardian, admin: true, students: ['s1']), {
          '/administration': null,
          '/club': '/my-children',
        });
      },
    );
  });
}
