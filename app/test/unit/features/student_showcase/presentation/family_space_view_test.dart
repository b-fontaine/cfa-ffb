import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/family_space_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

FamilyChild _child(String id, String name, {int validated = 0}) => FamilyChild(
  id: StudentId(id),
  firstName: name,
  showcase: StudentShowcase(
    firstName: name,
    rows: const [],
    current: null,
    validatedCount: validated,
    finishedTechniques: 0,
    techniqueCount: 0,
    toStart: validated == 0,
    passesRequired: 5,
  ),
);

FamilySession _session(String title, {String? group = 'Enfants du mardi'}) =>
    FamilySession(
      id: title,
      title: title,
      date: DateTime(2026, 10, 14),
      audience: Audience.children,
      groupName: group,
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    FamilySpace space, {
    StudentId? selected,
    ValueChanged<StudentId>? onSelect,
    bool stale = false,
  }) => pumpUi(
    tester,
    SingleChildScrollView(
      child: FamilySpaceView(
        space: space,
        selected: selected,
        onSelect: onSelect ?? (_) {},
        stale: stale,
      ),
    ),
  );

  group('FamilySpaceView', () {
    testWidgets('says so when nobody is linked yet', (tester) async {
      await pump(tester, const FamilySpace(children: [], upcoming: []));

      expect(
        find.text('No student is linked to your account yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a single child has no selector and shows the path', (
      tester,
    ) async {
      await pump(
        tester,
        FamilySpace(
          children: [_child('s1', 'Léa', validated: 1)],
          upcoming: const [],
        ),
      );

      expect(find.byType(ChildSelector), findsNothing);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('1 exercise validated'), findsOneWidget);
    });

    testWidgets('has no action of writing: no button, field or switch', (
      tester,
    ) async {
      await pump(
        tester,
        FamilySpace(
          children: [_child('s1', 'Léa')],
          upcoming: [_session('Rebond')],
        ),
      );

      for (final type in [
        FilledButton,
        ElevatedButton,
        OutlinedButton,
        TextButton,
        IconButton,
        FloatingActionButton,
        TextField,
        Switch,
        Checkbox,
      ]) {
        expect(find.byType(type), findsNothing, reason: '$type');
      }
      expect(find.text('Done'), findsNothing);
    });

    testWidgets(
      'two children: one chip each, the shown one is selected, tapping selects',
      (tester) async {
        final selected = <StudentId>[];
        await pump(
          tester,
          FamilySpace(
            children: [
              _child('s1', 'Léa', validated: 1),
              _child('s2', 'Tom', validated: 2),
            ],
            upcoming: const [],
          ),
          selected: const StudentId('s2'),
          onSelect: selected.add,
        );

        expect(find.text('2 exercises validated'), findsOneWidget);
        expect(find.text('1 exercise validated'), findsNothing);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tom'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Léa'))
              .selected,
          isFalse,
        );
        expect(find.text('L'), findsOneWidget, reason: 'initiale de Léa');
        expect(find.text('T'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Léa'));
        expect(selected, [const StudentId('s1')]);
      },
    );

    testWidgets('an unknown selection shows the first child', (tester) async {
      await pump(
        tester,
        FamilySpace(
          children: [_child('s1', 'Léa', validated: 1), _child('s2', 'Tom')],
          upcoming: const [],
        ),
        selected: const StudentId('s9'),
      );

      expect(find.text('1 exercise validated'), findsOneWidget);
    });

    testWidgets('the chips are at least 48 dp high and announced as a choice', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        FamilySpace(
          children: [_child('s1', 'Léa'), _child('s2', 'Tom')],
          upcoming: const [],
        ),
      );

      for (final name in ['Léa', 'Tom']) {
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.widgetWithText(ChoiceChip, name),
                      matching: find.byType(ConstrainedBox),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(find.bySemanticsLabel('Choose a child'), findsOneWidget);
      expect(
        tester.getSemantics(find.widgetWithText(ChoiceChip, 'Léa')),
        matchesSemantics(
          label: 'Léa',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('stays readable on a narrow screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilySpaceView(
                space: FamilySpace(
                  children: [
                    _child('s1', 'Marie-Charlotte', validated: 1),
                    _child('s2', 'Jean-Baptiste'),
                  ],
                  upcoming: [_session('Rebond au centre de la table')],
                ),
                selected: null,
                onSelect: (_) {},
                stale: true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ChildSelector), findsOneWidget);
    });

    testWidgets(
      'children with the same first name are numbered, never confused',
      (tester) async {
        await pump(
          tester,
          FamilySpace(
            children: [
              _child('s1', 'Léa'),
              _child('s2', 'Léa'),
              _child('s3', 'Tom'),
            ],
            upcoming: const [],
          ),
        );

        expect(find.text('Léa (1)'), findsOneWidget);
        expect(find.text('Léa (2)'), findsOneWidget);
        expect(find.text('Tom'), findsOneWidget);
      },
    );

    testWidgets(
      'the homonym number is composed by the view, in each language',
      (tester) async {
        for (final locale in AppLocalizations.supportedLocales) {
          await pumpUi(
            tester,
            SingleChildScrollView(
              child: FamilySpaceView(
                space: FamilySpace(
                  children: [_child('s1', 'Léa'), _child('s2', 'Léa')],
                  upcoming: const [],
                ),
                selected: null,
                onSelect: (_) {},
              ),
            ),
            locale: locale,
          );

          // Attendu écrit en dur, par langue : la clé testée n'est pas
          // utilisée pour calculer l'attendu.
          expect(find.text('Léa (1)'), findsOneWidget, reason: '$locale');
          expect(find.text('Léa (2)'), findsOneWidget, reason: '$locale');
        }
      },
    );

    testWidgets(
      'a child with no first name gets an icon, not a question mark',
      (tester) async {
        await pump(
          tester,
          FamilySpace(
            children: [_child('s1', ''), _child('s2', 'Tom')],
            upcoming: const [],
          ),
        );

        expect(find.text('?'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('child-s1')),
            matching: find.byIcon(Icons.person_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('lists the next sessions with their day and group', (
      tester,
    ) async {
      await pump(
        tester,
        FamilySpace(
          children: [_child('s1', 'Léa')],
          upcoming: [_session('Rebond'), _session('Libre', group: null)],
        ),
      );

      expect(find.text('Next sessions'), findsOneWidget);
      expect(find.text('Rebond'), findsOneWidget);
      expect(find.text('Wed, Oct 14 · Enfants du mardi'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('Wed, Oct 14'), findsOneWidget);
    });

    testWidgets('says so when no session is planned', (tester) async {
      await pump(
        tester,
        FamilySpace(children: [_child('s1', 'Léa')], upcoming: const []),
      );

      expect(find.text('No session is planned for now.'), findsOneWidget);
    });

    testWidgets(
      'tells the family it is read-only; offline: says the data is the latest',
      (tester) async {
        await pump(
          tester,
          FamilySpace(children: [_child('s1', 'Léa')], upcoming: const []),
        );
        expect(
          find.text(
            'You are viewing this information read-only. '
            'The coach keeps it up to date.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('You are offline'), findsNothing);

        await pump(
          tester,
          FamilySpace(children: [_child('s1', 'Léa')], upcoming: const []),
          stale: true,
        );
        expect(
          find.text(
            'You are offline: this is the latest information received.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('FamilyNotice', () {
    testWidgets('shows an icon, a header and an explanation', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        const FamilyNotice(
          icon: Icons.lock_outline,
          title: 'Titre',
          body: 'Corps',
        ),
      );

      expect(find.text('Titre'), findsOneWidget);
      expect(find.text('Corps'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Titre')),
        matchesSemantics(label: 'Titre', isHeader: true),
      );
      semantics.dispose();
    });
  });

  test('homonymRanks gives a rank only to the first names that repeat, in link '
      'order, and no text', () {
    final ranks = homonymRanks([
      _child('a', 'Léa'),
      _child('b', 'Tom'),
      _child('c', 'Léa'),
    ]);

    expect(ranks[const StudentId('a')], 1);
    expect(ranks[const StudentId('b')], isNull);
    expect(ranks[const StudentId('c')], 2);
    expect(ranks.containsKey(const StudentId('b')), isTrue);
  });
}
