import 'package:billard_cfa/app/auth/auth_redirect.dart';
import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
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
}
