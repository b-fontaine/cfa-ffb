import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/presentation/ui/session_review_view.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

final posture1 = ExerciseRef(blockId: 'posture', number: 1);

Student student(String name) => Student(
  id: StudentId(name),
  firstName: name,
  audienceHistory: [
    AudienceChange(
      audience: Audience.children,
      effectiveFrom: DateTime(2026, 9),
    ),
  ],
);

SessionReview review({
  SessionOutcome outcome = const SessionOutcome(),
  bool withGroup = true,
  bool withSheet = true,
}) => SessionReview(
  record: SessionRecord(
    id: const SessionId('r1'),
    groupId: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    date: DateTime(2026, 10, 12),
    audience: Audience.children,
    present: {const StudentId('Léa'), const StudentId('Hugo')},
  ),
  outcome: outcome,
  proposedDate: DateTime(2026, 10, 19),
  sheet: withSheet
      ? SheetOption(
          id: SheetId('posture-1'),
          technique: 'posture',
          techniqueRank: 1,
          title: 'Posture',
          part: 1,
          partCount: 2,
        )
      : null,
  group: withGroup
      ? Group(
          id: const GroupId('g1'),
          seasonId: const SeasonId('season'),
          name: 'Jeunes',
          audience: Audience.children,
        )
      : null,
  students: {
    const StudentId('Léa'): student('Léa'),
    const StudentId('Hugo'): student('Hugo'),
  },
  blockLabels: const {'posture': (title: 'Posture', proposal: false)},
);

Widget view(
  SessionReview review, {
  VoidCallback? onEnterResults,
  VoidCallback? onBackToday,
  Widget? next,
}) => SingleChildScrollView(
  child: SessionReviewView(
    review: review,
    next: next,
    onEnterResults: onEnterResults ?? () {},
    onOpenRecord: () {},
    onOpenStudent: (_) {},
    onBackToday: onBackToday ?? () {},
  ),
);

void main() {
  testWidgets('names the sheet, the date, the group and the present students', (
    tester,
  ) async {
    await pumpUi(tester, view(review()));

    expect(find.text('Posture, session 1/2'), findsOneWidget);
    expect(
      find.text('Mon, Oct 12 · Jeunes · 2 students present'),
      findsOneWidget,
    );
  });

  testWidgets('copes with a missing sheet and a missing group', (tester) async {
    await pumpUi(tester, view(review(withGroup: false, withSheet: false)));

    expect(find.text('Session without a catalogue session'), findsOneWidget);
    expect(find.text('Mon, Oct 12 · 2 students present'), findsOneWidget);
  });

  testWidgets('counts the passes, per exercise', (tester) async {
    await pumpUi(
      tester,
      view(
        review(
          outcome: SessionOutcome(
            totalPasses: 3,
            totalPassed: 2,
            byExercise: [
              ExercisePasses(exercise: posture1, passes: 3, passed: 2),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3 passes entered, 2 successful'), findsOneWidget);
    expect(find.text('Posture · exercise 1'), findsOneWidget);
    expect(find.text('3 passes, 2 successful'), findsOneWidget);
  });

  testWidgets('lists the validations by student', (tester) async {
    await pumpUi(
      tester,
      view(
        review(
          outcome: SessionOutcome(
            totalPasses: 1,
            totalPassed: 1,
            validations: [
              NewValidation(
                studentId: const StudentId('Léa'),
                exercise: posture1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Validated during this session'), findsOneWidget);
    expect(find.text('Léa validated Posture · exercise 1'), findsOneWidget);
  });

  testWidgets('says no exercise was validated', (tester) async {
    await pumpUi(
      tester,
      view(
        review(outcome: const SessionOutcome(totalPasses: 1, totalPassed: 1)),
      ),
    );

    expect(find.text('No exercise validated by this session.'), findsOneWidget);
  });

  testWidgets('names the present students without a pass and the alerts', (
    tester,
  ) async {
    await pumpUi(
      tester,
      view(
        review(
          outcome: SessionOutcome(
            totalPasses: 1,
            unrated: [const StudentId('Hugo')],
            watched: [
              WatchedStudent(
                studentId: const StudentId('Léa'),
                exercise: posture1,
                alert: AlertLevel.attention,
                consecutiveFailures: 3,
                otherAlerts: 0,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Present without a pass'), findsOneWidget);
    expect(find.text('Hugo'), findsOneWidget);
    expect(find.text('To watch'), findsOneWidget);
    expect(find.textContaining('3 failures in a row'), findsOneWidget);
  });

  testWidgets(
    'without any pass, offers to enter the results and hides the next',
    (tester) async {
      var entered = 0;
      await pumpUi(
        tester,
        view(
          review(),
          onEnterResults: () => entered++,
          next: const Text('next card'),
        ),
      );

      expect(find.text('No pass entered for this session.'), findsOneWidget);
      expect(find.text('next card'), findsNothing);
      await tester.tap(find.text('Enter the results'));
      expect(entered, 1);
    },
  );

  testWidgets('shows the next session slot once passes are entered', (
    tester,
  ) async {
    await pumpUi(
      tester,
      view(
        review(outcome: const SessionOutcome(totalPasses: 1, totalPassed: 1)),
        next: const Text('next card'),
      ),
    );

    expect(find.text('next card'), findsOneWidget);
  });

  testWidgets('goes back to Today', (tester) async {
    var back = 0;
    await pumpUi(tester, view(review(), onBackToday: () => back++));

    await tester.ensureVisible(find.text('Back to Today'));
    await tester.tap(find.text('Back to Today'));

    expect(back, 1);
  });
}
