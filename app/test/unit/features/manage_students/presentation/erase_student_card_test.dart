import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/ui/erase_student_card.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<StudentErasureEvent, StudentErasureState>
    implements StudentErasureBloc;

void main() {
  late _MockBloc bloc;
  var erased = 0;
  const id = StudentId('s1');

  setUpAll(() {
    registerFallbackValue(const StudentErasureEvent.stopRequested());
  });

  setUp(() {
    bloc = _MockBloc();
    erased = 0;
  });

  Future<void> pump(WidgetTester tester, StudentErasureState state) async {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<StudentErasureState>.empty(),
      initialState: state,
    );
    await pumpUi(
      tester,
      BlocProvider<StudentErasureBloc>.value(
        value: bloc,
        child: SingleChildScrollView(
          child: EraseStudentCard(
            studentId: id,
            studentName: 'Léa',
            onErased: () => erased++,
          ),
        ),
      ),
    );
  }

  const ready = StudentErasureState(status: StudentErasureStatus.ready);
  const club = StudentErasureState(
    status: StudentErasureStatus.ready,
    synchronized: true,
    preview: StudentPurgePreview(attempts: 3, presences: 2, accountLinks: 1),
  );

  testWidgets('opening the card reads what will be erased', (tester) async {
    await pump(tester, ready);

    verify(() => bloc.add(const StudentErasureEvent.inspected(studentId: id)))
        .called(1);
  });

  testWidgets('on the device the historical texts and confirmation stay', (
    tester,
  ) async {
    await pump(tester, ready);

    expect(find.textContaining('from this device'), findsOneWidget);
    expect(find.textContaining('linked records in the club'), findsNothing);
    await tester.tap(find.text('Erase Léa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('deleted from this device'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const StudentErasureEvent.requested(studentId: id)))
        .called(1);
  });

  testWidgets(
    'in the club the preview counts what will be erased, limits said',
    (tester) async {
      await pump(tester, club);

      expect(
        find.textContaining('the 6 linked records in the club'),
        findsOneWidget,
      );
      expect(find.textContaining('lose access to the sheet'), findsOneWidget);
      expect(
        find.textContaining('No trace of the erasure remains'),
        findsOneWidget,
      );
      expect(find.textContaining('local copy of this student'), findsOneWidget);
      await tester.tap(find.text('Erase Léa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('on every device'), findsOneWidget);
      expect(find.textContaining('you can resume it'), findsOneWidget);
    },
  );

  testWidgets(
    'a started erasure is offered for resumption without confirming again',
    (tester) async {
      await pump(tester, club.copyWith(inProgress: true));

      expect(
        find.textContaining('has started but is not finished'),
        findsOneWidget,
      );
      expect(find.text('Resume the erasure'), findsOneWidget);
      expect(find.text('Erase Léa'), findsNothing);
      await tester.tap(find.text('Resume the erasure'));
      await tester.pump();
      expect(find.text('Confirm'), findsNothing);
      verify(() => bloc.add(const StudentErasureEvent.requested(studentId: id)))
          .called(1);
    },
  );

  testWidgets('the progress is announced and the erasure can be stopped', (
    tester,
  ) async {
    await pump(
      tester,
      club.copyWith(status: StudentErasureStatus.working, done: 2, total: 5),
    );

    expect(find.text('Erasure in progress: step 2 of 5'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(LinearProgressIndicator)).label,
      'Erasure in progress: step 2 of 5',
    );
    await tester.tap(find.text('Stop after this step'));
    verify(() => bloc.add(const StudentErasureEvent.stopRequested())).called(1);
  });

  for (final (status, text) in [
    (StudentErasureStatus.interrupted, 'The erasure is interrupted'),
    (StudentErasureStatus.stopped, 'The erasure is stopped'),
    (StudentErasureStatus.paused, 'Today’s write limit is reached'),
  ]) {
    testWidgets('$status leaves the erasure to resume', (tester) async {
      await pump(tester, club.copyWith(status: status, inProgress: true));

      expect(find.textContaining(text), findsOneWidget);
      expect(find.text('Resume the erasure'), findsOneWidget);
    });
  }

  testWidgets('a failure is shown and the erasure stays to resume', (
    tester,
  ) async {
    await pump(
      tester,
      club.copyWith(
        status: StudentErasureStatus.failure,
        inProgress: true,
        failure: const ServiceFailure(ServiceFailureCode.denied),
      ),
    );

    expect(find.text('Resume the erasure'), findsOneWidget);
    expect(find.textContaining('not allowed'), findsOneWidget);
  });

  testWidgets('the end of the erasure tells the page', (tester) async {
    final states = Stream.fromIterable([
      club.copyWith(status: StudentErasureStatus.working),
      club.copyWith(status: StudentErasureStatus.erased),
    ]);
    when(() => bloc.state).thenReturn(club);
    whenListen(bloc, states, initialState: club);
    await pumpUi(
      tester,
      BlocProvider<StudentErasureBloc>.value(
        value: bloc,
        child: EraseStudentCard(
          studentId: id,
          studentName: 'Léa',
          onErased: () => erased++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(erased, 1);
  });
}
