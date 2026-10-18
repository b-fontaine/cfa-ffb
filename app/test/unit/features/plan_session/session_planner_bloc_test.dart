import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/list_plannable_groups.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fixtures.dart';

class _MockPlanSession extends Mock implements PlanSession;

class _MockListSessions extends Mock implements ListSessions;

class _MockListOptions extends Mock implements ListSheetOptions;

class _MockListGroups extends Mock implements ListPlannableGroups;

class _MockDeleteSession extends Mock implements DeleteSession;

void main() {
  final today = day(12);
  final session = Session(
    id: '1',
    title: 'a',
    date: today,
    audience: Audience.children,
  );
  final summary = PlannedSessionSummary(session: session);
  final option = SheetOption(
    id: SheetId('demi-bille-2'),
    technique: 'demi-bille',
    techniqueRank: 2,
    title: 'Quantité demi-bille',
    part: 2,
    partCount: 2,
  );
  final adults = Group(
    id: const GroupId('g2'),
    seasonId: const SeasonId('season'),
    name: 'Adultes',
    audience: Audience.adults,
  );
  late _MockPlanSession planSession;
  late _MockListSessions listSessions;
  late _MockListOptions listOptions;
  late _MockListGroups listGroups;
  late _MockDeleteSession deleteSession;

  setUp(() {
    planSession = _MockPlanSession();
    listSessions = _MockListSessions();
    listOptions = _MockListOptions();
    listGroups = _MockListGroups();
    deleteSession = _MockDeleteSession();
    when(listOptions.call).thenAnswer((_) async => Ok([option]));
    when(() => listGroups(today: today)).thenAnswer((_) async => [adults]);
  });

  SessionPlannerBloc build() => SessionPlannerBloc(
    planSession,
    listSessions,
    listOptions,
    listGroups,
    deleteSession,
  );

  /// État après un `started` sans lien profond.
  SessionPlannerState started({
    List<PlannedSessionSummary> sessions = const [],
  }) => SessionPlannerState(
    sessions: sessions,
    sheetOptions: [option],
    groups: [adults],
    date: today,
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'loads the sessions, the catalogue options, the groups and the day on '
    'start',
    setUp: () => when(listSessions.call).thenAnswer((_) async => [summary]),
    build: build,
    act: (bloc) => bloc.add(SessionPlannerEvent.started(today: today)),
    expect: () => [
      started(sessions: [summary]),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'preselects a known catalogue session and ignores an unknown one',
    setUp: () => when(listSessions.call).thenAnswer((_) async => const []),
    build: build,
    act: (bloc) => bloc
      ..add(
        SessionPlannerEvent.started(
          today: today,
          sheetId: SheetId('demi-bille-2'),
        ),
      )
      ..add(
        SessionPlannerEvent.started(
          today: today,
          sheetId: SheetId('inconnue-9'),
        ),
      ),
    expect: () => [
      started().copyWith(selectedSheet: SheetId('demi-bille-2')),
      started(),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'preselects a plannable group and ignores an unknown one',
    setUp: () => when(listSessions.call).thenAnswer((_) async => const []),
    build: build,
    act: (bloc) => bloc
      ..add(SessionPlannerEvent.started(today: today, groupId: adults.id))
      ..add(
        SessionPlannerEvent.started(
          today: today,
          groupId: const GroupId('inconnu'),
        ),
      ),
    expect: () => [started().copyWith(selectedGroup: adults.id), started()],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'plans without a catalogue session when the catalogue is unreadable',
    setUp: () {
      when(listSessions.call).thenAnswer((_) async => const []);
      when(listOptions.call)
          .thenAnswer((_) async => const Err(NotFound('sheet', 'x')));
    },
    build: build,
    act: (bloc) => bloc.add(SessionPlannerEvent.started(today: today)),
    expect: () => [
      SessionPlannerState(
        sheetsUnavailable: true,
        groups: [adults],
        date: today,
      ),
    ],
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
    'remembers the typed title',
    build: build,
    act: (bloc) =>
        bloc.add(const SessionPlannerEvent.titleEdited(title: 'Cours')),
    expect: () => const [SessionPlannerState(title: 'Cours')],
  );

  group('the group of the next session', () {
    blocTest<SessionPlannerBloc, SessionPlannerState>(
      'selects the chosen group',
      build: build,
      seed: () => SessionPlannerState(groups: [adults]),
      act: (bloc) => bloc.add(
        const SessionPlannerEvent.groupSelected(groupId: GroupId('g2')),
      ),
      expect: () => [
        SessionPlannerState(
          groups: [adults],
          selectedGroup: const GroupId('g2'),
        ),
      ],
    );

    blocTest<SessionPlannerBloc, SessionPlannerState>(
      'ignores a group that is not proposable',
      build: build,
      seed: () => SessionPlannerState(groups: [adults]),
      act: (bloc) => bloc.add(
        const SessionPlannerEvent.groupSelected(groupId: GroupId('ghost')),
      ),
      expect: () => const <SessionPlannerState>[],
    );
  });

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'remembers the chosen day',
    build: build,
    act: (bloc) => bloc.add(SessionPlannerEvent.dateChanged(date: day(19))),
    expect: () => [SessionPlannerState(date: day(19))],
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
    'plans the session with its day, group and catalogue session, reloads '
    'and clears the title and the sheet but keeps the day and the group',
    setUp: () {
      when(
        () => planSession(
          title: 'a',
          date: day(19),
          sheetId: SheetId('quart-1'),
          groupId: const GroupId('g2'),
        ),
      ).thenAnswer((_) async => session);
      when(listSessions.call).thenAnswer((_) async => [summary]);
    },
    build: build,
    seed: () => SessionPlannerState(
      groups: [adults],
      selectedSheet: SheetId('quart-1'),
      selectedGroup: const GroupId('g2'),
      date: day(19),
      title: 'a',
      prefilledTitle: 'a',
    ),
    act: (bloc) => bloc.add(const SessionPlannerEvent.sessionSubmitted()),
    expect: () => [
      SessionPlannerState(
        sessions: [summary],
        groups: [adults],
        selectedGroup: const GroupId('g2'),
        date: day(19),
        plannedCount: 1,
      ),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'does nothing before the day is known',
    build: build,
    act: (bloc) => bloc.add(const SessionPlannerEvent.sessionSubmitted()),
    expect: () => const <SessionPlannerState>[],
    verify: (_) => verifyZeroInteractions(planSession),
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'flags an invalid title, then clears the flag when it is edited',
    setUp: () =>
        when(() => planSession(title: '', date: today))
            .thenThrow(const InvalidSessionTitle()),
    build: build,
    seed: () => SessionPlannerState(date: today),
    act: (bloc) => bloc
      ..add(const SessionPlannerEvent.sessionSubmitted())
      ..add(const SessionPlannerEvent.titleEdited(title: 'a')),
    expect: () => [
      SessionPlannerState(date: today, titleInvalid: true),
      SessionPlannerState(date: today, title: 'a'),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'reports the missing group and plans nothing',
    setUp: () => when(() => planSession(title: 'a', date: today))
        .thenThrow(const InvariantViolation(InvariantCode.sessionNeedsGroup)),
    build: build,
    seed: () => SessionPlannerState(groups: [adults], date: today, title: 'a'),
    act: (bloc) => bloc.add(const SessionPlannerEvent.sessionSubmitted()),
    expect: () => [
      SessionPlannerState(
        groups: [adults],
        date: today,
        title: 'a',
        failure: const InvariantViolation(InvariantCode.sessionNeedsGroup),
      ),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'reports a refused rule, cleared by the next change of day or group',
    setUp: () => when(
      () => planSession(
        title: 'a',
        date: DateTime(2027, 7),
        groupId: const GroupId('g2'),
      ),
    ).thenThrow(const InvariantViolation(InvariantCode.seasonOutsidePeriod)),
    build: build,
    seed: () => SessionPlannerState(
      groups: [adults],
      selectedGroup: const GroupId('g2'),
      date: DateTime(2027, 7),
      title: 'a',
    ),
    act: (bloc) => bloc
      ..add(const SessionPlannerEvent.sessionSubmitted())
      ..add(SessionPlannerEvent.dateChanged(date: today)),
    expect: () => [
      SessionPlannerState(
        groups: [adults],
        selectedGroup: const GroupId('g2'),
        date: DateTime(2027, 7),
        title: 'a',
        failure: const InvariantViolation(InvariantCode.seasonOutsidePeriod),
      ),
      SessionPlannerState(
        groups: [adults],
        selectedGroup: const GroupId('g2'),
        date: today,
        title: 'a',
      ),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'deletes a planned session and reloads the list',
    setUp: () {
      when(() => deleteSession('1')).thenAnswer((_) async {});
      when(listSessions.call).thenAnswer((_) async => const []);
    },
    build: build,
    seed: () => SessionPlannerState(sessions: [summary]),
    act: (bloc) =>
        bloc.add(const SessionPlannerEvent.sessionDeleted(sessionId: '1')),
    verify: (_) => verify(() => deleteSession('1')).called(1),
    expect: () => [const SessionPlannerState()],
  );
}
