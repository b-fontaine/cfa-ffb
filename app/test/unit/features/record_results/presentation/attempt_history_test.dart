import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/record_results/domain/session_overview.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_edit_dialog.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_history.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fixtures.dart';
import '../../../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<RecordResultsEvent, RecordResultsState>
    implements RecordResultsBloc;

const _studentId = StudentId('s1');

SessionOverview _overview(List<ExerciseAttempt> attempts) => SessionOverview(
  session: SessionRecord(
    id: const SessionId('x1'),
    groupId: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    date: day(12),
    audience: Audience.children,
    present: {_studentId},
  ),
  groupName: 'Jeunes',
  students: [
    Student.enroll(
      id: _studentId,
      firstName: 'Léa',
      audience: Audience.children,
      since: DateTime(2026, 9),
    ),
  ],
  attempts: attempts,
  catalogue: buildCatalogue(),
  maxPassesPerExercise: 2,
  passesRequired: 5,
);

RecordResultsState _state({
  List<ExerciseAttempt> attempts = const [],
  AttemptChange? change,
  Failure? refused,
}) => RecordResultsState(
  status: RecordStatus.ready,
  overview: _overview(attempts),
  exercise: ref('a', 1),
  attemptChange: change,
  attemptRefused: refused,
);

void main() {
  late _MockBloc bloc;
  final pass = attempt(ref('a', 1), potted: 3);

  setUpAll(() {
    registerFallbackValue(
      const RecordResultsEvent.attemptDeleted(attemptId: AttemptId('a')),
    );
  });
  setUp(() => bloc = _MockBloc());

  Future<void> pump(WidgetTester tester, RecordResultsState state) {
    whenListen(
      bloc,
      const Stream<RecordResultsState>.empty(),
      initialState: state,
    );
    return pumpUi(
      tester,
      BlocProvider<RecordResultsBloc>.value(
        value: bloc,
        child: SingleChildScrollView(child: AttemptHistory(state: state)),
      ),
    );
  }

  testWidgets('lists the passes of the session', (tester) async {
    await pump(tester, _state(attempts: [pass]));

    expect(find.text('Pass 1: 3 of 5'), findsOneWidget);
    expect(find.byTooltip('Edit the pass of Léa (3 of 5)'), findsOneWidget);
    expect(find.byTooltip('Delete the pass of Léa (3 of 5)'), findsOneWidget);
  });

  testWidgets('draws read-only dots next to the pass text', (tester) async {
    await pump(tester, _state(attempts: [pass]));

    final dots = tester.widget<PassDots>(find.byType(PassDots));
    expect(dots.readOnly, isTrue);
    expect(dots.total, 5);
    expect(dots.value.where((pocketed) => pocketed), hasLength(3));
  });

  testWidgets('keeps the pass of an unknown student visible and editable', (
    tester,
  ) async {
    final stray = attempt(ref('a', 1), potted: 2, student: 'gone', id: 'a2');
    await pump(tester, _state(attempts: [stray]));

    expect(find.text('Student no longer in the group'), findsOneWidget);
    expect(find.text('Pass 1: 2 of 5'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('says when a pass was corrected or deleted', (tester) async {
    await pump(
      tester,
      _state(
        attempts: [pass],
        change: AttemptChange.corrected(attempt: pass),
      ),
    );
    expect(find.text('Pass corrected: 3 of 5'), findsOneWidget);

    await pump(tester, _state(change: const AttemptChange.deleted()));
    expect(find.text('Pass deleted.'), findsOneWidget);
  });

  testWidgets('shows why a change was refused, in the error colour', (
    tester,
  ) async {
    const refused = InvariantViolation(InvariantCode.totalBelowSheet);
    await pump(tester, _state(attempts: [pass], refused: refused));

    final context = tester.element(find.byType(AttemptHistory));
    final message = failureMessage(AppLocalizations.of(context), refused);
    final text = tester.widget<Text>(find.text(message));

    expect(text.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('saving the correction asks the bloc to correct', (tester) async {
    await pump(tester, _state(attempts: [pass]));

    await tester.tap(find.byTooltip('Edit the pass of Léa (3 of 5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More balls potted in the correction'));
    await tester.pump();
    await tester.tap(find.text('Save the correction'));
    await tester.pumpAndSettle();

    expect(find.byType(AttemptEditDialog), findsNothing);
    verify(
      () => bloc.add(
        RecordResultsEvent.attemptCorrected(
          attemptId: pass.id,
          potted: 4,
          total: 5,
        ),
      ),
    ).called(1);
  });

  testWidgets('deleting asks for a confirmation first', (tester) async {
    await pump(tester, _state(attempts: [pass]));

    await tester.tap(find.byTooltip('Delete the pass of Léa (3 of 5)'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this pass?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any()));

    await tester.tap(find.byTooltip('Delete the pass of Léa (3 of 5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(RecordResultsEvent.attemptDeleted(attemptId: pass.id)),
    ).called(1);
  });

  testWidgets('cannot edit a pass whose exercise left the catalogue', (
    tester,
  ) async {
    final orphan = attempt(ref('zzz', 1), potted: 3);
    await pump(tester, _state(attempts: [orphan]));

    final edit = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Edit the pass of Léa (3 of 5)'),
        matching: find.byType(IconButton),
      ),
    );

    expect(edit.onPressed, isNull);
    expect(find.text('Pass 1: 3 of 5'), findsOneWidget);
  });
}
