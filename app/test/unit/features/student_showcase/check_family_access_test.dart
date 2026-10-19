import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/membership/domain/own_link.dart';
import 'package:billard_cfa/entities/membership/domain/own_link_source.dart';
import 'package:billard_cfa/features/student_showcase/domain/check_family_access.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Link implements OwnLinkSource {
  _Link(this.answer);

  final Future<OwnLink?> Function() answer;

  @override
  Future<OwnLink?> read() => answer();

  @override
  Stream<OwnLink?> watch() => const Stream.empty();
}

OwnLink _link(Set<String> students) => OwnLink(
  role: Role.guardian,
  studentIds: {for (final id in students) StudentId(id)},
  groupIds: const {},
);

/// Ce que le serveur dit du lien du compte, face aux fiches de sa session :
/// la règle « accès retiré » (et « retiré en partie ») est ici, pas dans
/// l'écran.
void main() {
  final scope = SessionScope()
    ..signIn(const UserId('u1'))
    ..activate(
      const ClubId('c1'),
      Role.guardian,
      studentIds: const [StudentId('s1'), StudentId('s2')],
    );

  Future<FamilyAccess> check(Future<OwnLink?> Function() answer) =>
      CheckFamilyAccess(_Link(answer), scope)();

  Set<StudentId> granted(FamilyAccess access) =>
      (access as AccessGranted).studentIds;

  test('a link to every student of the session grants them all', () async {
    final access = await check(() async => _link({'s1', 's2'}));

    expect(granted(access), {const StudentId('s1'), const StudentId('s2')});
  });

  test('a link that lost one student grants the other one only', () async {
    final access = await check(() async => _link({'s1'}));

    expect(granted(access), {const StudentId('s1')});
  });

  test('a student linked now but not in the session is not granted', () async {
    final access = await check(() async => _link({'s2', 's9'}));

    expect(granted(access), {const StudentId('s2')});
  });

  test('no member any more is a revoked access', () async {
    expect(await check(() async => null), isA<AccessRevoked>());
  });

  // Limite connue de FB6 (ADR 0024, notes FB6) : seule `studentIds` est
  // confrontée. Mesuré à l'émulateur (family.test.mjs, « known limit ») : le
  // serveur ne refuse pas les écoutes déjà ouvertes d'un groupe retiré, la
  // lecture de l'écran qui se recharge est servie, donc l'écran garde ses
  // séances ; à la modification suivante d'une séance du groupe l'écoute est
  // refusée et, le lien existant encore, l'écran passe à « Accès refusé »
  // (`family_space_cubit_test`, « a refusal while the link still exists »).
  // FB7 relira la portée : ce test devra alors casser.
  test(
    'known limit: a group removed from the link is not seen until FB7',
    () async {
      final scopeWithGroup = SessionScope()
        ..signIn(const UserId('u1'))
        ..activate(
          const ClubId('c1'),
          Role.guardian,
          studentIds: const [StudentId('s1')],
          groupIds: const [GroupId('g1')],
        );

      final access = await CheckFamilyAccess(
        _Link(
          () async => const OwnLink(
            role: Role.guardian,
            studentIds: {StudentId('s1')},
            groupIds: {},
          ),
        ),
        scopeWithGroup,
      )();

      expect(granted(access), {const StudentId('s1')});
    },
  );

  test('a link that lists no student is a revoked access', () async {
    expect(await check(() async => _link({})), isA<AccessRevoked>());
  });

  test('a link with none of the students of the session is revoked', () async {
    expect(await check(() async => _link({'s9'})), isA<AccessRevoked>());
  });

  test(
    'a link that cannot be read for lack of network changes nothing',
    () async {
      final access = await check(
        () async => throw const ServiceFailure(ServiceFailureCode.unavailable),
      );

      expect(granted(access), {const StudentId('s1'), const StudentId('s2')});
    },
  );
}
