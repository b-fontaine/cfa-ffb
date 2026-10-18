import 'dart:io';

import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les bornes de `firestore.rules` des dépôts de planification (FB4b) sont
/// dans le domaine : l'utilisateur lit un message de formulaire, jamais « droit
/// refusé » parce qu'un nom ou une liste dépasse ce que le serveur accepte.
void main() {
  InvariantCode codeOf(void Function() body) {
    try {
      body();
    } on InvariantViolation catch (violation) {
      return violation.code;
    }
    fail('aucune violation levée');
  }

  Season season(String label) => Season(
    id: const SeasonId('se'),
    label: label,
    startDate: DateTime(2026, 9),
    endDate: DateTime(2027, 8, 31),
  );

  Group group(String name) => Group(
    id: const GroupId('g'),
    seasonId: const SeasonId('se'),
    name: name,
    audience: Audience.children,
  );

  SessionRecord record(int present) => SessionRecord(
    id: const SessionId('r'),
    groupId: const GroupId('g'),
    seasonId: const SeasonId('se'),
    date: DateTime(2026, 10),
    audience: Audience.children,
    present: {for (var i = 0; i < present; i++) StudentId('s$i')},
  );

  test('a season label has at most the length the rules accept', () {
    expect(season('a' * maxSeasonLabelLength).label, hasLength(80));
    expect(
      codeOf(() => season('a' * (maxSeasonLabelLength + 1))),
      InvariantCode.nameTooLong,
    );
  });

  test('a group name is checked when typed, not when read back', () {
    expect(
      () => requireGroupNameFits('a' * maxGroupNameLength),
      returnsNormally,
    );
    expect(
      codeOf(() => requireGroupNameFits('a' * (maxGroupNameLength + 1))),
      InvariantCode.nameTooLong,
    );
    expect(
      codeOf(() => group('Jeunes').rename('a' * (maxGroupNameLength + 1))),
      InvariantCode.nameTooLong,
    );
    expect(group('a' * 500).name, hasLength(500), reason: 'donnée ancienne');
  });

  test('the present students are checked when typed, not when read back', () {
    expect(
      () => requirePresentFit(record(maxPresentStudents).present),
      returnsNormally,
    );
    expect(
      codeOf(() => requirePresentFit(record(maxPresentStudents + 1).present)),
      InvariantCode.tooManyPresent,
    );
    expect(record(500).present, hasLength(500), reason: 'donnée ancienne');
  });

  test('the limits are the ones of firestore.rules', () {
    final rules = File('../firestore.rules').readAsStringSync();
    expect(
      rules,
      contains(
        'd.label.size() >= 1 && d.label.size() <= $maxSeasonLabelLength',
      ),
    );
    expect(
      rules,
      contains('d.name.size() >= 1 && d.name.size() <= $maxGroupNameLength'),
    );
    expect(rules, contains("optString(d, 'title', $maxSessionTitleLength)"));
    expect(rules, contains('idList(d.presentStudentIds, $maxPresentStudents)'));
    // Références de séance : un passage (`sessionId`) cite l'identifiant d'une
    // saisie, une saisie cite sa séance planifiée.
    expect(
      rules,
      contains("optString(d, 'sessionId', $maxSessionReferenceLength)"),
    );
    expect(
      rules,
      contains("optString(d, 'plannedSessionId', $maxSessionReferenceLength)"),
    );
  });
}
