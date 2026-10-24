import 'dart:io';

import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/operations_world.dart';
import '../../support/stale_markers_world.dart';

/// Parité entre `firestore.rules`, qui fait foi, et ce que le domaine et les
/// **faux serveurs** des scénarios en recopient (FB8 partie B). Les scénarios
/// BDD jouent ces faux : si les règles changent sans eux, ce test échoue au
/// lieu de laisser les scénarios verts sur des règles qui n'existent plus.
/// Les règles elles-mêmes sont prouvées contre l'émulateur
/// (`scripts/rules_test/`).
void main() {
  final rules = File('../firestore.rules').readAsStringSync();

  Set<String> rolesIn(String list) => {
    for (final match in RegExp("'([a-z]+)'").allMatches(list)) match[1]!,
  };

  test('the 90-day net: rules, domain and fake server agree', () {
    final match = RegExp(
      r"function staleMarkerAge\(\) \{ return duration\.value\((\d+), 'd'\); \}",
    ).firstMatch(rules);

    expect(match, isNotNull, reason: 'staleMarkerAge() introuvable');
    final days = int.parse(match![1]!);
    expect(staleMarkerAge, Duration(days: days));
    expect(StaleMarkerRulesStore.ruleAge, Duration(days: days));
  });

  test('the invitations a director lists: rules, roles policy and fake '
      'server agree, and never a director invitation', () {
    final match = RegExp(
      r'allow list: if \(isDirector\(resource\.data\.clubId\)\s*'
      r'&& resource\.data\.role in \[([^\]]*)\]\)',
    ).firstMatch(rules);

    expect(match, isNotNull, reason: 'allow list des invitations introuvable');
    final listed = rolesIn(match![1]!);
    expect(listed, isNot(contains('director')));
    expect(listed, OperationsRulesStore.directorInvites);
    expect(listed, {
      for (final role in Role.director.invitableRoles) role.name,
    });
  });

  test('any member lists the invitations they created, never without the '
      'club or the author (the fake server copies this branch)', () {
    expect(
      rules,
      contains(
        '|| (resource.data.createdBy == request.auth.uid '
        '&& isMember(resource.data.clubId));',
      ),
    );
  });

  test('the members a director manages are the roles they invite', () {
    final match = RegExp(
      r'function directorMemberRoles\(\) \{ return \[([^\]]*)\]; \}',
    ).firstMatch(rules);

    expect(match, isNotNull, reason: 'directorMemberRoles() introuvable');
    expect(rolesIn(match![1]!), {
      for (final role in Role.director.invitableRoles) role.name,
    });
  });
}
