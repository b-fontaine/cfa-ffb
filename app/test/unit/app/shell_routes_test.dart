import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/app/shell.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShell.indexOf', () {
    test(
      'selects the Sessions destination for the catalogue and its pages',
      () {
        expect(AppShell.indexOf('/catalogue'), 3);
        expect(AppShell.indexOf('/catalogue/demi-bille-2'), 3);
      },
    );

    test('keeps the suggestion and the exercise sheets under Sessions', () {
      expect(AppShell.indexOf('/session'), 3);
      expect(AppShell.indexOf('/exercises/puissance/1'), 3);
    });

    test('keeps the other destinations', () {
      expect(AppShell.indexOf('/'), 0);
      expect(AppShell.indexOf('/students/s1'), 1);
      expect(AppShell.indexOf('/record/x1'), 2);
    });

    test('keeps the session summary under Results', () {
      expect(AppShell.indexOf('/record/x1/review'), 2);
    });

    test('keeps the planner under Sessions', () {
      expect(AppShell.indexOf('/planner'), 3);
    });

    test('selects More for its list and for the backup', () {
      expect(AppShell.indexOf('/more'), 4);
      expect(AppShell.indexOf('/backup'), 4);
    });
  });

  group('AppShell.sessionsTabOf', () {
    test('maps the three screens of Sessions to their tab', () {
      expect(AppShell.sessionsTabOf('/planner'), 0);
      expect(AppShell.sessionsTabOf('/catalogue'), 1);
      expect(AppShell.sessionsTabOf('/session'), 2);
    });

    test('ignores a trailing slash', () {
      expect(AppShell.sessionsTabOf('/catalogue/'), 1);
    });

    test('shows no tab on the pages opened from a tab', () {
      expect(AppShell.sessionsTabOf('/catalogue/demi-bille-2'), isNull);
      expect(AppShell.sessionsTabOf('/exercises/puissance/1'), isNull);
      expect(AppShell.sessionsTabOf('/students'), isNull);
      expect(AppShell.sessionsTabOf('/'), isNull);
    });
  });

  group('AppRoutes.review', () {
    test('addresses the summary of a record', () {
      expect(AppRoutes.review(const SessionId('x1')), '/record/x1/review');
    });
  });

  group('AppRoutes.sheet', () {
    test('addresses a session of the catalogue', () {
      expect(
        AppRoutes.sheet(SheetId('demi-bille-2')),
        '/catalogue/demi-bille-2',
      );
    });

    test('carries the audience when given', () {
      expect(
        AppRoutes.sheet(SheetId('demi-bille-2'), audience: Audience.adults),
        '/catalogue/demi-bille-2?audience=adults',
      );
    });
  });

  group('AppRoutes.sheet origin', () {
    final id = SheetId('demi-bille-2');

    test('the planner origin keeps its address', () {
      expect(
        AppRoutes.sheet(
          id,
          audience: Audience.adults,
          origin: SheetOrigin.planner,
        ),
        '/catalogue/demi-bille-2?audience=adults&from=planner',
      );
      expect(
        AppRoutes.sheet(id, origin: SheetOrigin.planner),
        '/catalogue/demi-bille-2?from=planner',
      );
    });

    test('the today origin is marked, the catalogue origin is not', () {
      expect(
        AppRoutes.sheet(id, origin: SheetOrigin.today),
        '/catalogue/demi-bille-2?from=today',
      );
      expect(AppRoutes.sheet(id), '/catalogue/demi-bille-2');
    });

    test('carries the chosen group of the catalogue', () {
      expect(
        AppRoutes.sheet(id, group: const GroupId('g1')),
        '/catalogue/demi-bille-2?group=g1',
      );
    });
  });

  group('SheetOrigin.parse', () {
    test('reads the three known values', () {
      expect(SheetOrigin.parse('planner'), SheetOrigin.planner);
      expect(SheetOrigin.parse('today'), SheetOrigin.today);
      expect(SheetOrigin.parse('catalogue'), SheetOrigin.catalogue);
    });

    test('falls back to the catalogue on an absent or unknown value', () {
      expect(SheetOrigin.parse(null), SheetOrigin.catalogue);
      expect(SheetOrigin.parse(''), SheetOrigin.catalogue);
      expect(SheetOrigin.parse('evil'), SheetOrigin.catalogue);
      expect(SheetOrigin.parse('https://evil.example'), SheetOrigin.catalogue);
    });
  });

  group('AppRoutes.catalogueFor', () {
    test('addresses the catalogue, with the group when chosen', () {
      expect(AppRoutes.catalogueFor(null), '/catalogue');
      expect(
        AppRoutes.catalogueFor(const GroupId('g1')),
        '/catalogue?group=g1',
      );
    });
  });

  group('AppRoutes.guide and AppRoutes.presentation', () {
    final id = SheetId('demi-bille-2');

    test('use the same segments as the routes', () {
      expect(AppRoutes.guideSegment, 'guide');
      expect(AppRoutes.presentationSegment, 'presentation');
      expect(AppRoutes.guide(id), '/catalogue/demi-bille-2/guide');
      expect(
        AppRoutes.presentation(id),
        '/catalogue/demi-bille-2/presentation',
      );
    });

    test('carry the audience, the planned session and the step', () {
      expect(
        AppRoutes.guide(id, audience: Audience.adults, session: 'p1', step: 6),
        '/catalogue/demi-bille-2/guide?audience=adults&session=p1&step=6',
      );
    });

    test('carry the group the guided session was launched for', () {
      expect(
        AppRoutes.guide(
          id,
          audience: Audience.adults,
          group: const GroupId('g1'),
        ),
        '/catalogue/demi-bille-2/guide?audience=adults&group=g1',
      );
    });

    test('keep the planned session through the presentation round trip', () {
      expect(
        AppRoutes.presentation(
          id,
          audience: Audience.adults,
          session: 'p1',
          step: 6,
        ),
        '/catalogue/demi-bille-2/presentation'
        '?audience=adults&session=p1&step=6',
      );
    });
  });

  group('AppRoutes.presentation with a group', () {
    test('keeps the group of the guided session', () {
      expect(
        AppRoutes.presentation(
          SheetId('demi-bille-2'),
          group: const GroupId('g1'),
        ),
        '/catalogue/demi-bille-2/presentation?group=g1',
      );
    });
  });

  group('AppRoutes.recordFromPlan', () {
    test('carries the group, the day and the catalogue session', () {
      final uri = Uri.parse(
        AppRoutes.recordFromPlan(
          group: const GroupId('g1'),
          date: DateTime(2026, 10, 19, 9, 30),
          sheet: SheetId('puissance-1'),
        ),
      );

      expect(uri.path, AppRoutes.newRecord);
      expect(uri.queryParameters, {
        'group': 'g1',
        'date': '2026-10-19',
        'sheet': 'puissance-1',
      });
    });

    test('leaves out the catalogue session of a free session', () {
      final uri = Uri.parse(
        AppRoutes.recordFromPlan(
          group: const GroupId('g1'),
          date: DateTime(2026, 10, 19),
        ),
      );

      expect(uri.queryParameters.keys, isNot(contains('sheet')));
    });
  });

  group('AppRoutes.plan', () {
    test('preselects the catalogue session and the audience', () {
      expect(
        AppRoutes.plan(SheetId('puissance-1'), audience: Audience.adults),
        '/planner?sheet=puissance-1&audience=adults',
      );
    });

    test('opens the planner without catalogue session', () {
      expect(
        AppRoutes.plan(null, audience: Audience.children),
        '/planner?audience=children',
      );
      expect(AppRoutes.plan(null), '/planner');
    });
  });

  group('AppRoutes.recordFromSuggestion', () {
    test('carries the group, the block, the recall and the session', () {
      final uri = Uri.parse(
        AppRoutes.recordFromSuggestion(
          group: const GroupId('g1'),
          main: 'posture',
          recall: 'puissance',
          sheet: SheetId('posture-2'),
        ),
      );

      expect(uri.path, AppRoutes.newRecord);
      expect(uri.queryParameters, {
        'group': 'g1',
        'main': 'posture',
        'recall': 'puissance',
        'sheet': 'posture-2',
      });
    });

    test('leaves out the recall and the session when there are none', () {
      final uri = Uri.parse(
        AppRoutes.recordFromSuggestion(
          group: const GroupId('g1'),
          main: 'quantites-de-billes',
        ),
      );

      expect(uri.queryParameters, {
        'group': 'g1',
        'main': 'quantites-de-billes',
      });
    });
  });
}
