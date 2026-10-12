import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanSession extends Mock implements PlanSession;

class _MockListSessions extends Mock implements ListSessions;

void main() {
  const session = Session(id: '1', title: 'a', audience: Audience.children);
  late _MockPlanSession planSession;
  late _MockListSessions listSessions;

  setUp(() {
    planSession = _MockPlanSession();
    listSessions = _MockListSessions();
  });

  SessionPlannerBloc build() => SessionPlannerBloc(planSession, listSessions);

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'loads the sessions on start',
    setUp: () => when(listSessions.call).thenAnswer((_) async => [session]),
    build: build,
    act: (bloc) => bloc.add(const SessionPlannerEvent.started()),
    expect: () => [
      const SessionPlannerState(sessions: [session]),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'plans a session then reloads the list',
    setUp: () {
      when(() => planSession(title: 'a', audience: Audience.children))
          .thenAnswer((_) async => session);
      when(listSessions.call).thenAnswer((_) async => [session]);
    },
    build: build,
    act: (bloc) => bloc.add(
      const SessionPlannerEvent.sessionSubmitted(
        title: 'a',
        audience: Audience.children,
      ),
    ),
    expect: () => [
      const SessionPlannerState(sessions: [session]),
    ],
  );

  blocTest<SessionPlannerBloc, SessionPlannerState>(
    'flags an invalid title',
    setUp: () =>
        when(() => planSession(title: '', audience: Audience.adults))
            .thenThrow(const InvalidSessionTitle()),
    build: build,
    act: (bloc) => bloc.add(
      const SessionPlannerEvent.sessionSubmitted(
        title: '',
        audience: Audience.adults,
      ),
    ),
    expect: () => [const SessionPlannerState(titleInvalid: true)],
  );
}
