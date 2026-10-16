import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/next_sheet_card.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

SheetSuggestion suggestion({
  SheetSuggestionKind kind = SheetSuggestionKind.nextPending,
  DateTime? lastGivenOn,
}) => SheetSuggestion(
  option: SheetOption(
    id: SheetId('posture-2'),
    technique: 'posture',
    techniqueRank: 1,
    title: 'Posture',
    part: 2,
    partCount: 2,
  ),
  kind: kind,
  exerciseNumbers: [1],
  headCovered: true,
  head: ExerciseRef(blockId: 'posture', number: 1),
  lastGivenOn: lastGivenOn,
);

NextSheetCard card({
  SheetSuggestion? sheet,
  NextSheetPlanning planning = NextSheetPlanning.idle,
  String? failureMessage,
  VoidCallback? onPlan,
  VoidCallback? onChangeDate,
  VoidCallback? onOpenPlanner,
  VoidCallback? onOpenPlanned,
}) => NextSheetCard(
  sheet: sheet,
  date: DateTime(2026, 10, 19),
  planning: planning,
  failureMessage: failureMessage,
  onPlan: onPlan ?? () {},
  onChangeDate: onChangeDate ?? () {},
  onOpenPlanner: onOpenPlanner ?? () {},
  onOpenPlanned: onOpenPlanned ?? () {},
);

void main() {
  testWidgets('proposes the session, its part and the date with Plan', (
    tester,
  ) async {
    var planned = 0;
    await pumpUi(tester, card(sheet: suggestion(), onPlan: () => planned++));

    expect(find.text('Next session'), findsOneWidget);
    expect(find.text('Posture'), findsOneWidget);
    expect(find.text('Session 2/2'), findsOneWidget);
    expect(find.text('A part still to do for this group'), findsOneWidget);
    expect(find.text('Proposed for Mon, Oct 19'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    expect(planned, 1);
  });

  testWidgets('says when the session is given again, with its date', (
    tester,
  ) async {
    await pumpUi(
      tester,
      card(
        sheet: suggestion(
          kind: SheetSuggestionKind.repeat,
          lastGivenOn: DateTime(2026, 10, 5),
        ),
      ),
    );

    expect(find.text('Already given on Mon, Oct 5'), findsOneWidget);
  });

  testWidgets('changes the date', (tester) async {
    var changed = 0;
    await pumpUi(
      tester,
      card(sheet: suggestion(), onChangeDate: () => changed++),
    );

    await tester.tap(find.text('Change the date'));

    expect(changed, 1);
  });

  testWidgets('without a catalogue session, falls back to the planner', (
    tester,
  ) async {
    var opened = 0;
    await pumpUi(tester, card(onOpenPlanner: () => opened++));

    expect(
      find.textContaining('No catalogue session for this notion'),
      findsOneWidget,
    );
    expect(find.text('Plan'), findsNothing);
    await tester.tap(find.text('Open the planner'));
    expect(opened, 1);
  });

  testWidgets('disables the button while planning', (tester) async {
    await pumpUi(
      tester,
      card(sheet: suggestion(), planning: NextSheetPlanning.planning),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Planning…'), findsOneWidget);
  });

  testWidgets('replaces the button by the planned date and a link', (
    tester,
  ) async {
    var opened = 0;
    await pumpUi(
      tester,
      card(
        sheet: suggestion(),
        planning: NextSheetPlanning.planned,
        onOpenPlanned: () => opened++,
      ),
    );

    expect(find.text('Planned for Mon, Oct 19'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Change the date'), findsNothing);
    await tester.tap(find.text('See in Planned'));
    expect(opened, 1);
  });

  testWidgets('shows a session already planned instead of the button', (
    tester,
  ) async {
    await pumpUi(
      tester,
      card(sheet: suggestion(), planning: NextSheetPlanning.already),
    );

    expect(find.text('Already planned for Mon, Oct 19'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
  });

  testWidgets('shows a refusal with the planner link, without red', (
    tester,
  ) async {
    await pumpUi(
      tester,
      card(
        sheet: suggestion(),
        failureMessage: 'This date is outside the season.',
      ),
    );

    expect(find.text('This date is outside the season.'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Open the planner'), findsOneWidget);
  });
}
