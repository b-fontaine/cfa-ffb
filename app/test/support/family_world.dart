import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_world.dart';

/// Amorçage et observation de l'espace d'un parent ou d'un élève dans les
/// scénarios : le compte est lié aux fiches (son `member`) et à leurs groupes
/// du jour, tels que l'invitation les écrit.
class FamilyWorld {
  FamilyWorld._();

  /// Le compte [email] (créé, adresse vérifiée) est [role] de [students] dans
  /// [club] ; ses groupes sont ceux où ces élèves sont membres aujourd'hui.
  static Future<void> follow(
    WidgetTester tester, {
    required String email,
    required String role,
    required String club,
    required List<String> students,
  }) async {
    await UiWorld.prepare(tester);
    final account =
        UiWorld.auth.accountOf(email) ??
        UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
    final ids = <StudentId>[];
    final groups = <GroupId>{};
    await tester.runAsync(() async {
      final day = DateTime(
        UiWorld.today.year,
        UiWorld.today.month,
        UiWorld.today.day,
      );
      final all = await UiWorld.seedGraph<GroupRepository>().all();
      for (final name in students) {
        final id = (await UiWorld.studentNamed(name)).id;
        ids.add(id);
        for (final group in all) {
          if (group.isMemberOn(id, day)) groups.add(group.id);
        }
      }
    });
    UiWorld.memberships.grant(
      account.id,
      ClubMembership(
        clubId: UiWorld.clubIdOf(club),
        clubName: club,
        role: UiWorld.role(role),
        groupIds: groups.toList(),
        studentIds: ids,
      ),
      displayName: email.split('@').first,
    );
  }

  /// Le club retire l'accès du compte [email] : son `member` est supprimé, les
  /// règles ne lui laissent plus rien lire dans le club (les écoutes ouvertes
  /// sont refusées et se ferment).
  static Future<void> removeAccess(WidgetTester tester, String email) async {
    final account = UiWorld.auth.accountOf(email)!;
    final club = UiWorld.clubIdOf(UiWorld.defaultClub);
    UiWorld.memberships.remove(account.id, club);
    UiWorld.documents.revoke('clubs/${club.value}/');
    await UiWorld.settle(tester);
  }

  /// Le club retire **une seule** fiche, [student], du `member` de [email] :
  /// le `member` ne la liste plus et les règles n'en laissent plus rien lire
  /// (les écoutes ouvertes sur cette fiche sont refusées et se ferment).
  static Future<void> removeLink(
    WidgetTester tester,
    String email,
    String student,
  ) async {
    final account = UiWorld.auth.accountOf(email)!;
    final club = UiWorld.clubIdOf(UiWorld.defaultClub);
    final id = (await tester.runAsync(() => UiWorld.studentNamed(student)))!.id;
    final path = 'clubs/${club.value}/members/${account.id.value}';
    final member = UiWorld.documents.read(path)!;
    UiWorld.documents.seed(path, {
      ...member,
      'studentIds': [
        for (final linked in member['studentIds']! as List<Object?>)
          if (linked != id.value) linked,
      ],
    });
    UiWorld.documents.revoke('clubs/${club.value}/students/${id.value}');
    await UiWorld.settle(tester);
  }

  /// Tout ce que l'appareil de la scène a demandé au serveur (lectures,
  /// écoutes, écritures), pour les assertions d'isolation.
  static List<String> get requests => UiWorld.device.requests;

  /// L'identifiant de la fiche de [name] dans le club.
  static Future<String> studentId(WidgetTester tester, String name) async {
    final student = await tester.runAsync(() => UiWorld.studentNamed(name));
    return student!.id.value;
  }
}
