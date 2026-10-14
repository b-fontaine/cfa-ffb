import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/app/shell.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
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
      expect(AppShell.indexOf('/planner'), 0);
      expect(AppShell.indexOf('/students/s1'), 1);
      expect(AppShell.indexOf('/record/x1'), 2);
      expect(AppShell.indexOf('/backup'), 4);
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

  group('AppRoutes.sheet from the planner', () {
    test('marks the origin so that the back button returns to it', () {
      expect(
        AppRoutes.sheet(
          SheetId('demi-bille-2'),
          audience: Audience.adults,
          fromPlanner: true,
        ),
        '/catalogue/demi-bille-2?audience=adults&from=planner',
      );
      expect(
        AppRoutes.sheet(SheetId('demi-bille-2'), fromPlanner: true),
        '/catalogue/demi-bille-2?from=planner',
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

  group('AppRoutes.recordFromGuide', () {
    final exercise = ExerciseRef(blockId: 'demi-bille', number: 3);

    test('carries the block, the exercise and the way back', () {
      final uri = Uri.parse(
        AppRoutes.recordFromGuide(
          exercise: exercise,
          from: '/catalogue/demi-bille-2/guide?step=3',
          recall: 'bille-pleine',
        ),
      );

      expect(uri.path, AppRoutes.newRecord);
      expect(AppRoutes.newRecord, '/record/new');
      expect(uri.queryParameters, {
        'main': 'demi-bille',
        'recall': 'bille-pleine',
        'exercise': '3',
        'from': '/catalogue/demi-bille-2/guide?step=3',
      });
    });

    test('carries the group, the absentees and the date already chosen', () {
      final uri = Uri.parse(
        AppRoutes.recordFromGuide(
          exercise: exercise,
          from: '/catalogue/demi-bille-2/guide?step=3',
          group: const GroupId('g1'),
          absent: {const StudentId('s1'), const StudentId('s2')},
          date: DateTime(2026, 10, 3),
        ),
      );

      expect(uri.queryParameters['group'], 'g1');
      expect(uri.queryParameters['absent'], 's1,s2');
      expect(uri.queryParameters['date'], '2026-10-03');
    });

    test('carries the catalogue session noted by the record', () {
      final uri = Uri.parse(
        AppRoutes.recordFromGuide(
          exercise: exercise,
          from: '/catalogue/demi-bille-2/guide?step=3',
          sheet: SheetId('demi-bille-2'),
        ),
      );

      expect(uri.queryParameters['sheet'], 'demi-bille-2');
    });

    test('leaves out what was not chosen', () {
      final uri = Uri.parse(
        AppRoutes.recordFromGuide(exercise: exercise, from: '/catalogue/x-1'),
      );

      expect(uri.queryParameters.keys, containsAll(['main', 'exercise']));
      expect(uri.queryParameters.keys, isNot(contains('group')));
      expect(uri.queryParameters.keys, isNot(contains('absent')));
      expect(uri.queryParameters.keys, isNot(contains('date')));
      expect(uri.queryParameters.keys, isNot(contains('sheet')));
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
