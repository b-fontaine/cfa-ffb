import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/session_sheet_fixtures.dart';

void main() {
  late DomainWorld world;
  late SuggestNextSheet next;

  setUp(() async {
    world = DomainWorld(
      config: RulesConfig(passesRequired: 1),
      sheets: sheetsOnTestBlocks(),
    );
    await world.seedClub(studentNames: ['s1', 's2']);
    next = SuggestNextSheet(
      SuggestSession(
        world.groups,
        world.sessions,
        world.attempts,
        world.acquisitions,
        world.catalogueRepository,
        world.config,
        world.sheets,
        FixedClock(DateTime(2026, 10, 12)),
      ),
    );
  });

  test('refuses an unknown group', () async {
    final result = await next(
      groupId: const GroupId('nope'),
      present: {const StudentId('s1')},
    );

    expect(err(result), isA<NotFound>());
  });

  test('gives the audience of the group and the main block', () async {
    final result = ok(
      await next(
        groupId: const GroupId('g1'),
        present: {const StudentId('s1'), const StudentId('s2')},
      ),
    );

    expect(result.audience, Audience.children);
    expect(result.mainBlockId, 'a');
  });

  test('carries the sheet suggested by the session rule', () async {
    final result = ok(
      await next(
        groupId: const GroupId('g1'),
        present: {const StudentId('s1')},
      ),
    );

    expect(result.sheet?.kind, SheetSuggestionKind.coversHead);
  });
}
