import 'package:billard_cfa/features/acknowledge_alert/presentation/bloc/acknowledgement_bloc.dart';
import 'package:billard_cfa/features/manage_students/presentation/bloc/student_erasure_bloc.dart';
import 'package:billard_cfa/features/place_student/presentation/bloc/placement_bloc.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/student_recall_bloc.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/student_sheet_bloc.dart';
import 'package:billard_cfa/pages/student_sheet/presentation/student_sheet_page.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';
import '../../support/sheet_world.dart';
import '../shared/ui/pump_ui.dart';

/// Le bouton (Material) qui porte [text], icône comprise.
Finder buttonWith(String text) => find.ancestor(
  of: find.text(text),
  matching: find.bySubtype<ButtonStyleButton>(),
);

class _MockSheet extends MockBloc<StudentSheetEvent, StudentSheetState>
    implements StudentSheetBloc;

class _MockRecall extends MockBloc<StudentRecallEvent, StudentRecallState>
    implements StudentRecallBloc;

class _MockPlacement extends MockBloc<PlacementEvent, PlacementState>
    implements PlacementBloc;

class _MockErasure extends MockBloc<StudentErasureEvent, StudentErasureState>
    implements StudentErasureBloc;

class _MockAck extends MockBloc<AcknowledgementEvent, AcknowledgementState>
    implements AcknowledgementBloc;

void main() {
  late _MockSheet sheetBloc;
  late _MockRecall recall;
  late _MockPlacement placement;
  late _MockErasure erasure;
  late _MockAck ack;
  var shown = 0;

  setUpAll(() {
    registerFallbackValue(const StudentSheetEvent.refreshed());
    registerFallbackValue(
      AcknowledgementEvent.acknowledgeRequested(
        studentId: const StudentId('s1'),
        exercise: ref('a', 1),
      ),
    );
  });

  setUp(() {
    sheetBloc = _MockSheet();
    recall = _MockRecall();
    placement = _MockPlacement();
    erasure = _MockErasure();
    ack = _MockAck();
    shown = 0;
    whenListen(
      recall,
      const Stream<StudentRecallState>.empty(),
      initialState: const StudentRecallState(),
    );
    whenListen(
      placement,
      const Stream<PlacementState>.empty(),
      initialState: const PlacementState(),
    );
    whenListen(
      erasure,
      const Stream<StudentErasureState>.empty(),
      initialState: const StudentErasureState(),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    SheetWorld world, {
    Stream<AcknowledgementState> acks = const Stream.empty(),
  }) async {
    final sheet = await world.sheet(tester);
    whenListen(
      sheetBloc,
      const Stream<StudentSheetState>.empty(),
      initialState: StudentSheetState(
        status: StudentSheetStatus.ready,
        sheet: sheet,
      ),
    );
    whenListen(ack, acks, initialState: const AcknowledgementState());
    await pumpUi(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<StudentSheetBloc>.value(value: sheetBloc),
          BlocProvider<StudentRecallBloc>.value(value: recall),
          BlocProvider<PlacementBloc>.value(value: placement),
          BlocProvider<StudentErasureBloc>.value(value: erasure),
          BlocProvider<AcknowledgementBloc>.value(value: ack),
        ],
        child: StudentSheetPage(
          today: () => DateTime(2026, 10, 12),
          onBack: () {},
          onEdit: () {},
          onOpenAssessment: () {},
          onErased: () {},
          onShow: () => shown++,
        ),
      ),
    );
  }

  testWidgets('Seen asks to acknowledge the alert of the student', (
    tester,
  ) async {
    final world = SheetWorld();
    await world.start();
    await world.passes(ref('a', 1), 3, pass: false);
    await pump(tester, world);

    await tester.ensureVisible(find.text('Seen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seen'));

    verify(
      () => ack.add(
        AcknowledgementEvent.acknowledgeRequested(
          studentId: const StudentId('s1'),
          exercise: ref('a', 1),
        ),
      ),
    ).called(1);
  });

  testWidgets('Restore asks to restore a seen alert', (tester) async {
    final world = SheetWorld();
    await world.start();
    await world.passes(ref('a', 1), 3, pass: false);
    await world.acknowledge(ref('a', 1));
    await pump(tester, world);

    await tester.ensureVisible(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));

    verify(
      () => ack.add(
        AcknowledgementEvent.restoreRequested(
          studentId: const StudentId('s1'),
          exercise: ref('a', 1),
        ),
      ),
    ).called(1);
  });

  testWidgets('a done acknowledgement reloads the sheet and says so', (
    tester,
  ) async {
    final world = SheetWorld();
    await world.start();
    await world.passes(ref('a', 1), 3, pass: false);
    await pump(
      tester,
      world,
      acks: Stream.value(
        AcknowledgementState(
          status: AcknowledgementStatus.done,
          action: AcknowledgementAction.acknowledge,
          exercise: ref('a', 1),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alert marked as seen.'), findsOneWidget);
    verify(() => sheetBloc.add(const StudentSheetEvent.refreshed())).called(1);
  });

  testWidgets('a restored alert says so', (tester) async {
    final world = SheetWorld();
    await world.start();
    await world.passes(ref('a', 1), 3, pass: false);
    await pump(
      tester,
      world,
      acks: Stream.value(
        AcknowledgementState(
          status: AcknowledgementStatus.done,
          action: AcknowledgementAction.restore,
          exercise: ref('a', 1),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alert restored.'), findsOneWidget);
  });

  testWidgets('a refused acknowledgement shows the reason, not a success', (
    tester,
  ) async {
    final world = SheetWorld();
    await world.start();
    await pump(
      tester,
      world,
      acks: Stream.value(
        AcknowledgementState(
          status: AcknowledgementStatus.refused,
          action: AcknowledgementAction.acknowledge,
          exercise: ref('a', 1),
          failure: const InvariantViolation(InvariantCode.alertNotActive),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'This alert is no longer active: there is nothing to acknowledge.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alert marked as seen.'), findsNothing);
  });

  testWidgets('offers to show the sheet to the student, above the path', (
    tester,
  ) async {
    final world = SheetWorld();
    await world.start();
    await pump(tester, world);

    final button = buttonWith('Show to the student');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(button).dy,
      lessThan(tester.getTopLeft(find.text('Path')).dy),
    );
    await tester.tap(button);
    expect(shown, 1);
  });

  testWidgets('keeps the rare actions below the path', (tester) async {
    final world = SheetWorld();
    await world.start();
    await pump(tester, world);

    final path = tester.getTopLeft(find.text('Path')).dy;
    for (final label in ['Edit the first name', 'Maturity review']) {
      expect(tester.getTopLeft(find.text(label)).dy, greaterThan(path));
    }
    expect(find.text('Performance curves'), findsOneWidget);
  });
}
