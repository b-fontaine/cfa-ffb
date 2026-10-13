import 'dart:async';

import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
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
    registerFallbackValue(const SessionPlannerEvent.started());
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

  testWidgets('shows and changes the audience through the bloc', (
    tester,
  ) async {
    await pump(
      tester,
      SessionPlannerState(sheetOptions: options, audience: Audience.adults),
    );
    final selected = tester
        .widget<SegmentedButton<Audience>>(
          find.byType(SegmentedButton<Audience>),
        )
        .selected;
    expect(selected, {Audience.adults});

    await tester.tap(find.text('Children'));

    verify(
      () => bloc.add(
        const SessionPlannerEvent.audienceChanged(audience: Audience.children),
      ),
    ).called(1);
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
}
