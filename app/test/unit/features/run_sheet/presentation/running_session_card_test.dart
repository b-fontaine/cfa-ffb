import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/running_session_card.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

RunningSession running({DateTime? date}) => RunningSession(
  key: RunKey(sheetId: SheetId('posture-1')),
  step: 5,
  stepCount: 10,
  phase: SessionPhase.training,
  sheetTitle: 'Posture',
  part: 1,
  partCount: 2,
  plannedDate: date,
);

void main() {
  testWidgets('shows the state, the title, the step and the actions', (
    tester,
  ) async {
    await pumpUi(
      tester,
      RunningSessionCard(session: running(), onResume: () {}, onAbandon: () {}),
    );

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Posture, session 1/2'), findsOneWidget);
    expect(find.text('Step 6 of 10'), findsOneWidget);
    expect(find.text('Resume at step 6'), findsOneWidget);
    expect(find.text('Abandon'), findsOneWidget);
  });

  testWidgets('names the group and the date of the planned session', (
    tester,
  ) async {
    await pumpUi(
      tester,
      RunningSessionCard(
        session: running(date: DateTime(2026, 10, 14)),
        groupName: 'Jeunes',
        onResume: () {},
        onAbandon: () {},
      ),
    );

    expect(find.text('Wed, Oct 14 · Jeunes'), findsOneWidget);
  });

  testWidgets('resumes and abandons', (tester) async {
    var resumed = 0;
    var abandoned = 0;
    await pumpUi(
      tester,
      RunningSessionCard(
        session: running(),
        onResume: () => resumed++,
        onAbandon: () => abandoned++,
      ),
    );

    await tester.tap(find.text('Resume at step 6'));
    await tester.tap(find.text('Abandon'));

    expect((resumed, abandoned), (1, 1));
  });

  testWidgets('the compact row names the session and resumes', (tester) async {
    var resumed = 0;
    await pumpUi(
      tester,
      RunningSessionRow(session: running(), onResume: () => resumed++),
    );

    expect(
      find.text('Another session under way: Posture, session 1/2'),
      findsOneWidget,
    );
    await tester.tap(find.text('Resume'));
    expect(resumed, 1);
  });
}
