import 'dart:async';

import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SessionPlannerEvent, SessionPlannerState>
    implements SessionPlannerBloc;

SheetOption _option(String technique, int rank, int part, int parts) =>
    SheetOption(
      id: SheetId('$technique-$part'),
      technique: technique,
      techniqueRank: rank,
      title: 'Titre $technique',
      part: part,
      partCount: parts,
    );

void main() {
  late _MockBloc bloc;
  final options = [
    _option('puissance', 1, 1, 2),
    _option('puissance', 1, 2, 2),
    _option('quart', 2, 1, 1),
  ];

  setUpAll(() {
    registerFallbackValue(
      SessionPlannerEvent.started(today: DateTime(2026, 10, 12)),
    );
  });
  setUp(() => bloc = _MockBloc());

  Future<void> pump(
    WidgetTester tester,
    SessionPlannerState initial, {
    Stream<SessionPlannerState>? states,
  }) async {
    whenListen(
      bloc,
      states ?? const Stream<SessionPlannerState>.empty(),
      initialState: initial,
    );
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(
      tester,
      BlocProvider<SessionPlannerBloc>.value(
        value: bloc,
        child: const PlanSessionForm(),
      ),
    );
  }

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('groups the catalogue sessions by technique in the picker', (
    tester,
  ) async {
    await pump(tester, SessionPlannerState(sheetOptions: options));

    await tester.tap(find.byKey(const ValueKey('planner-sheet-field')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a catalogue session'), findsOneWidget);
    expect(find.text('1. Titre puissance'), findsOneWidget);
    expect(find.text('2. Titre quart'), findsOneWidget);
    expect(find.text('Session 1/2'), findsOneWidget);
    expect(find.text('Session 2/2'), findsOneWidget);
    expect(find.text('Session 1/1'), findsOneWidget);
  });

  testWidgets('asks the bloc to select the chosen session or none', (
    tester,
  ) async {
    await pump(
      tester,
      SessionPlannerState(
        sheetOptions: options,
        selectedSheet: SheetId('quart-1'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('planner-sheet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-option:puissance-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planner-sheet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-option:none')));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        SessionPlannerEvent.sheetSelected(sheetId: SheetId('puissance-2')),
      ),
    ).called(1);
    verify(() => bloc.add(const SessionPlannerEvent.sheetSelected())).called(1);
  });

  testWidgets('closing the picker keeps the current choice', (tester) async {
    await pump(tester, SessionPlannerState(sheetOptions: options));

    await tester.tap(find.byKey(const ValueKey('planner-sheet-field')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any()));
  });

  testWidgets('proposes the localized title of the chosen session', (
    tester,
  ) async {
    await pump(
      tester,
      SessionPlannerState(sheetOptions: options),
      states: Stream.fromIterable([
        SessionPlannerState(
          sheetOptions: options,
          selectedSheet: SheetId('puissance-2'),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        const SessionPlannerEvent.titleSuggested(
          title: 'Titre puissance, session 2/2',
        ),
      ),
    ).called(1);
  });

  testWidgets('shows the title held by the bloc and follows its changes', (
    tester,
  ) async {
    final controller = StreamController<SessionPlannerState>();
    addTearDown(controller.close);
    await pump(
      tester,
      SessionPlannerState(sheetOptions: options, title: 'Départ'),
      states: controller.stream,
    );
    expect(titleText(tester), 'Départ');

    controller.add(SessionPlannerState(sheetOptions: options, title: 'Autre'));
    await tester.pump();

    expect(titleText(tester), 'Autre');
  });

  testWidgets('empties the field once a session is planned', (tester) async {
    await pump(
      tester,
      SessionPlannerState(sheetOptions: options, title: 'Cours'),
      states: Stream.fromIterable([
        SessionPlannerState(sheetOptions: options, plannedCount: 1),
      ]),
    );
    await tester.pumpAndSettle();

    expect(titleText(tester), isEmpty);
  });

  testWidgets('reports what is typed to the bloc', (tester) async {
    await pump(tester, SessionPlannerState(sheetOptions: options));

    await tester.enterText(find.byType(TextField), 'Cours');

    verify(
      () => bloc.add(const SessionPlannerEvent.titleEdited(title: 'Cours')),
    ).called(1);
  });

  testWidgets('has no audience choice: it is the audience of the group', (
    tester,
  ) async {
    await pump(tester, SessionPlannerState(sheetOptions: options));

    expect(find.byType(SegmentedButton<Audience>), findsNothing);
  });

  testWidgets('submits the session held by the bloc', (tester) async {
    await pump(tester, SessionPlannerState(sheetOptions: options));

    await tester.tap(find.text('Add session'));

    verify(() => bloc.add(const SessionPlannerEvent.sessionSubmitted()))
        .called(1);
  });

  testWidgets('disables the picker when the catalogue is unreadable', (
    tester,
  ) async {
    await pump(tester, const SessionPlannerState(sheetsUnavailable: true));

    await tester.tap(find.byKey(const ValueKey('planner-sheet-field')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a catalogue session'), findsNothing);
    expect(
      find.textContaining('The session catalogue could not be read'),
      findsOneWidget,
    );
  });

  testWidgets('flags an invalid title', (tester) async {
    await pump(tester, const SessionPlannerState(titleInvalid: true));

    expect(find.text('The session title is required.'), findsOneWidget);
  });

  group('the group of the session', () {
    final groups = [
      Group(
        id: const GroupId('g1'),
        seasonId: const SeasonId('season'),
        name: 'Jeunes',
        audience: Audience.children,
      ),
      Group(
        id: const GroupId('g2'),
        seasonId: const SeasonId('season'),
        name: 'Adultes',
        audience: Audience.adults,
      ),
    ];

    testWidgets('lists the groups and asks the bloc to select one', (
      tester,
    ) async {
      await pump(tester, SessionPlannerState(groups: groups));

      await tester.tap(find.byKey(const ValueKey('planner-group-field')));
      await tester.pumpAndSettle();
      // Le champ (valeur à choisir) et le titre de la feuille.
      expect(find.text('Choose a group'), findsNWidgets(2));
      expect(find.text('Jeunes · Children'), findsOneWidget);
      expect(find.text('Adultes · Adults'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-option:g2')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const SessionPlannerEvent.groupSelected(groupId: GroupId('g2')),
        ),
      ).called(1);
    });

    testWidgets('offers no way to plan without a group', (tester) async {
      await pump(tester, SessionPlannerState(groups: groups));
      await tester.tap(find.byKey(const ValueKey('planner-group-field')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('group-option:none')), findsNothing);
      expect(find.byKey(const ValueKey('group-option:g2')), findsOneWidget);
    });

    testWidgets('shows the chosen group with its audience', (tester) async {
      await pump(
        tester,
        SessionPlannerState(groups: groups, selectedGroup: const GroupId('g2')),
      );

      expect(find.text('Adultes · Adults'), findsOneWidget);
    });

    testWidgets('disables the picker when the club has no group', (
      tester,
    ) async {
      await pump(tester, const SessionPlannerState());

      await tester.tap(find.byKey(const ValueKey('planner-group-field')));
      await tester.pumpAndSettle();

      expect(
        find.text('Create a group first to plan a session.'),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('the day of the session', () {
    testWidgets('shows the day and asks the bloc to change it', (tester) async {
      await pump(tester, SessionPlannerState(date: DateTime(2026, 10, 12)));

      expect(find.text('Session date'), findsOneWidget);
      expect(find.text('Mon, Oct 12'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('planner-change-date')));
      await tester.pumpAndSettle();
      final dialog = find.byType(DatePickerDialog);
      await tester.tap(find.descendant(of: dialog, matching: find.text('19')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          SessionPlannerEvent.dateChanged(date: DateTime(2026, 10, 19)),
        ),
      ).called(1);
    });

    testWidgets('shows no day before the bloc knows it', (tester) async {
      await pump(tester, const SessionPlannerState());

      expect(find.text('Session date'), findsNothing);
    });
  });

  testWidgets('shows the rule refused by the last planning', (tester) async {
    await pump(
      tester,
      const SessionPlannerState(
        failure: InvariantViolation(InvariantCode.seasonOutsidePeriod),
      ),
    );

    expect(find.text('This date is outside the season.'), findsOneWidget);
  });
}
