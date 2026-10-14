import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/list_recorded_sessions.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';

class _MockListRecordedSessions extends Mock implements ListRecordedSessions;

void main() {
  late _MockListRecordedSessions list;
  final summary = RecordedSessionSummary(
    session: SessionRecord(
      id: const SessionId('x1'),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: day(12),
      audience: Audience.children,
      present: {const StudentId('s1')},
    ),
    groupName: 'Jeunes',
    mainBlock: null,
    attemptCount: 2,
  );

  setUp(() => list = _MockListRecordedSessions());

  blocTest<RecordedSessionsBloc, RecordedSessionsState>(
    'lists the recorded sessions',
    build: () {
      when(() => list()).thenAnswer((_) async => Ok([summary]));
      return RecordedSessionsBloc(list);
    },
    act: (bloc) => bloc.add(const RecordedSessionsEvent.started()),
    expect: () => [
      const RecordedSessionsState(),
      RecordedSessionsState(
        status: RecordedSessionsStatus.ready,
        sessions: [summary],
      ),
    ],
  );

  blocTest<RecordedSessionsBloc, RecordedSessionsState>(
    'reports a failure',
    build: () {
      when(() => list())
          .thenAnswer((_) async => const Err(NotFound('group', 'g1')));
      return RecordedSessionsBloc(list);
    },
    act: (bloc) => bloc.add(const RecordedSessionsEvent.started()),
    expect: () => [
      const RecordedSessionsState(),
      const RecordedSessionsState(
        status: RecordedSessionsStatus.failure,
        failure: NotFound('group', 'g1'),
      ),
    ],
  );

  blocTest<RecordedSessionsBloc, RecordedSessionsState>(
    'reloads on refresh',
    build: () {
      when(() => list()).thenAnswer((_) async => Ok([summary]));
      return RecordedSessionsBloc(list);
    },
    seed: () =>
        const RecordedSessionsState(status: RecordedSessionsStatus.ready),
    act: (bloc) => bloc.add(const RecordedSessionsEvent.refreshed()),
    expect: () => [
      const RecordedSessionsState(),
      RecordedSessionsState(
        status: RecordedSessionsStatus.ready,
        sessions: [summary],
      ),
    ],
    verify: (_) => verify(() => list()).called(1),
  );
}
