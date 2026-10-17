import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with nobody and no club', () {
    final scope = SessionScope();

    expect(scope.id, isNull);
    expect(scope.clubId, isNull);
    expect(scope.role, isNull);
  });

  test('signing in forgets the club of the previous user', () {
    final scope = SessionScope()
      ..signIn(const UserId('u1'))
      ..activate(const ClubId('c1'), Role.teacher)
      ..signIn(const UserId('u2'));

    expect(scope.id, const UserId('u2'));
    expect(scope.clubId, isNull);
    expect(scope.role, isNull);
  });

  test('activating a club exposes its id and the role in it', () {
    final scope = SessionScope()
      ..signIn(const UserId('u1'))
      ..activate(const ClubId('c1'), Role.director);

    expect(scope.clubId, const ClubId('c1'));
    expect(scope.role, Role.director);

    scope.deactivateClub();

    expect(scope.id, const UserId('u1'));
    expect(scope.clubId, isNull);
  });

  test('signing out clears everything', () {
    final scope = SessionScope()
      ..signIn(const UserId('u1'))
      ..activate(const ClubId('c1'), Role.guardian)
      ..signOut();

    expect(scope.id, isNull);
    expect(scope.clubId, isNull);
    expect(scope.role, isNull);
  });
}
