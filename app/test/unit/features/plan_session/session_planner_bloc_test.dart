import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanSession extends Mock implements PlanSession;

class _MockListSessions extends Mock implements ListSessions;

class _MockListOptions extends Mock implements ListSheetOptions;

class _MockDeleteSession extends Mock implements DeleteSession;

void main() {
  const session = Session(id: '1', title: 'a', audience: Audience.children);
  final option = SheetOption(
    id: SheetId('demi-bille-2'),
    technique: 'demi-bille',
    techniqueRank: 2,
    title: 'Quantité demi-bille',
    part: 2,
    partCount: 2,
  );
  late _MockPlanSession planSession;
  late _MockListSessions listSessions;
  late _MockListOptions listOptions;
  late _MockDeleteSession deleteSession;

  setUp(() {
    planSession = _MockPlanSession();
    listSessions = _MockListSessions();
    listOptions = _MockListOptions();
    deleteSession = _MockDeleteSession();
    when(listOptions.call).thenAnswer((_) async => Ok([option]));
  });

  SessionPlannerBloc build() =>
      SessionPlannerBloc(planSession, listSessions, listOptions, deleteSession);

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'loads the sessions and the catalogue options on start',
    setUp: () => when(listSessions.call).thenAnswer((_) async => [session]),
    build: build,
    act: (bloc) => bloc.add(const SessionPlannerEvent.started()),
    expect: () => [
      SessionPlannerState(sessions: const [session], sheetOptions: [option]),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'preselects a known catalogue session and ignores an unknown one',
    setUp: () => when(listSessions.call).thenAnswer((_) async => const []),
    build: build,
    act: (bloc) => bloc
      ..add(SessionPlannerEvent.started(sheetId: SheetId('demi-bille-2')))
      ..add(SessionPlannerEvent.started(sheetId: SheetId('inconnue-9'))),
    expect: () => [
      SessionPlannerState(
        sheetOptions: [option],
        selectedSheet: SheetId('demi-bille-2'),
      ),
      SessionPlannerState(sheetOptions: [option]),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'plans without a catalogue session when the catalogue is unreadable',
    setUp: () {
      when(listSessions.call).thenAnswer((_) async => const []);
      when(listOptions.call)
          .thenAnswer((_) async => const Err(NotFound('sheet', 'x')));
    },
    build: build,
    act: (bloc) => bloc.add(const SessionPlannerEvent.started()),
    expect: () => [const SessionPlannerState(sheetsUnavailable: true)],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'selects then clears the catalogue session',
    build: build,
    act: (bloc) => bloc
      ..add(SessionPlannerEvent.sheetSelected(sheetId: SheetId('quart-1')))
      ..add(const SessionPlannerEvent.sheetSelected()),
    expect: () => [
      SessionPlannerState(selectedSheet: SheetId('quart-1')),
      const SessionPlannerState(),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'takes the audience of the deep link on start',
    setUp: () => when(listSessions.call).thenAnswer((_) async => const []),
    build: build,
    act: (bloc) =>
        bloc.add(const SessionPlannerEvent.started(audience: Audience.adults)),
    expect: () => [
      SessionPlannerState(sheetOptions: [option], audience: Audience.adults),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'remembers the audience and the typed title',
    build: build,
    act: (bloc) => bloc
      ..add(
        const SessionPlannerEvent.audienceChanged(audience: Audience.adults),
      )
      ..add(const SessionPlannerEvent.titleEdited(title: 'Cours')),
    expect: () => const [
      SessionPlannerState(audience: Audience.adults),
      SessionPlannerState(audience: Audience.adults, title: 'Cours'),
    ],
  );

  group('the title proposed by a catalogue session', () {
    blocTest<SessionPlannerBloc, SessionPlannerState>(
      'fills an empty title and is replaced by the next proposal',
      build: build,
      act: (bloc) => bloc
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Un'))
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Deux')),
      expect: () => const [
        SessionPlannerState(title: 'Un', prefilledTitle: 'Un'),
        SessionPlannerState(title: 'Deux', prefilledTitle: 'Deux'),
      ],
    );

    blocTest<SessionPlannerBloc, SessionPlannerState>(
      'never replaces a title the instructor has edited',
      build: build,
      act: (bloc) => bloc
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Un'))
        ..add(const SessionPlannerEvent.titleEdited(title: 'Mon titre'))
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Deux')),
      expect: () => const [
        SessionPlannerState(title: 'Un', prefilledTitle: 'Un'),
        SessionPlannerState(title: 'Mon titre', prefilledTitle: 'Un'),
      ],
    );

    blocTest<SessionPlannerBloc, SessionPlannerState>(
      'takes over again once the instructor empties the title',
      build: build,
      act: (bloc) => bloc
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Un'))
        ..add(const SessionPlannerEvent.titleEdited(title: ''))
        ..add(const SessionPlannerEvent.titleSuggested(title: 'Deux')),
      expect: () => const [
        SessionPlannerState(title: 'Un', prefilledTitle: 'Un'),
        SessionPlannerState(prefilledTitle: 'Un'),
        SessionPlannerState(title: 'Deux', prefilledTitle: 'Deux'),
      ],
    );
  });

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'plans the selected catalogue session, reloads and clears the form',
    setUp: () {
      when(
        () => planSession(
          title: 'a',
          audience: Audience.adults,
          sheetId: SheetId('quart-1'),
        ),
      ).thenAnswer((_) async => session);
      when(listSessions.call).thenAnswer((_) async => [session]);
    },
    build: build,
    seed: () => SessionPlannerState(
      selectedSheet: SheetId('quart-1'),
      audience: Audience.adults,
      title: 'a',
      prefilledTitle: 'a',
    ),
    act: (bloc) => bloc.add(const SessionPlannerEvent.sessionSubmitted()),
    expect: () => const [
      SessionPlannerState(
        sessions: [session],
        audience: Audience.adults,
        plannedCount: 1,
      ),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'flags an invalid title, then clears the flag when it is edited',
    setUp: () =>
        when(() => planSession(title: '', audience: Audience.children))
            .thenThrow(const InvalidSessionTitle()),
    build: build,
    act: (bloc) => bloc
      ..add(const SessionPlannerEvent.sessionSubmitted())
      ..add(const SessionPlannerEvent.titleEdited(title: 'a')),
    expect: () => const [
      SessionPlannerState(titleInvalid: true),
      SessionPlannerState(title: 'a'),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'deletes a planned session and reloads the list',
    setUp: () {
      when(() => deleteSession('1')).thenAnswer((_) async {});
      when(listSessions.call).thenAnswer((_) async => const []);
    },
    build: build,
    seed: () => const SessionPlannerState(sessions: [session]),
    act: (bloc) =>
        bloc.add(const SessionPlannerEvent.sessionDeleted(sessionId: '1')),
    verify: (_) => verify(() => deleteSession('1')).called(1),
    expect: () => [const SessionPlannerState()],
  );
}
