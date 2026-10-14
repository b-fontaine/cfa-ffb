import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/recorded_sessions_bloc.dart';
import 'package:billard_cfa/pages/record_history/presentation/record_history_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';
import '../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<RecordedSessionsEvent, RecordedSessionsState>
    implements RecordedSessionsBloc;

void main() {
  late _MockBloc bloc;
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

  setUpAll(() => registerFallbackValue(const RecordedSessionsEvent.started()));
  setUp(() => bloc = _MockBloc());

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<SessionId>? onOpenSession,
    VoidCallback? onNewSession,
  }) => pumpUi(
    tester,
    BlocProvider<RecordedSessionsBloc>.value(
      value: bloc,
      child: RecordHistoryPage(
        onOpenSession: onOpenSession ?? (_) {},
        onNewSession: onNewSession ?? () {},
      ),
    ),
  );

  void listen(RecordedSessionsState state) => whenListen(
    bloc,
    const Stream<RecordedSessionsState>.empty(),
    initialState: state,
  );

  testWidgets('shows the loading state', (tester) async {
    listen(const RecordedSessionsState());

    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the failure and retries through the bloc', (tester) async {
    listen(
      const RecordedSessionsState(
        status: RecordedSessionsStatus.failure,
        failure: NotFound('group', 'g1'),
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Retry'));

    verify(() => bloc.add(const RecordedSessionsEvent.refreshed())).called(1);
  });

  testWidgets('offers a new session when nothing was recorded', (tester) async {
    listen(const RecordedSessionsState(status: RecordedSessionsStatus.ready));
    var opened = 0;
    await pump(tester, onNewSession: () => opened++);

    expect(find.text('Recorded sessions'), findsOneWidget);
    expect(find.text('No session recorded yet.'), findsOneWidget);
    await tester.tap(find.text('New session'));

    expect(opened, 1);
  });

  testWidgets('opens a recorded session', (tester) async {
    listen(
      RecordedSessionsState(
        status: RecordedSessionsStatus.ready,
        sessions: [summary],
      ),
    );
    SessionId? opened;
    await pump(tester, onOpenSession: (id) => opened = id);

    await tester.tap(find.textContaining('Oct 12'));

    expect(opened, const SessionId('x1'));
  });
}
