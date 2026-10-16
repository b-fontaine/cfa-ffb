import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/track_progress/domain/watch_list.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/watched_students_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/week_summary_card.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

WatchedLine line(
  String name, {
  AlertLevel alert = AlertLevel.attention,
  int failures = 3,
  int others = 0,
}) => WatchedLine(
  student: Student(
    id: StudentId(name),
    firstName: name,
    audienceHistory: [
      AudienceChange(
        audience: Audience.children,
        effectiveFrom: DateTime(2026, 9),
      ),
    ],
  ),
  watched: WatchedStudent(
    studentId: StudentId(name),
    exercise: ExerciseRef(blockId: 'posture', number: 1),
    alert: alert,
    consecutiveFailures: failures,
    otherAlerts: others,
  ),
);

const Map<String, ({bool proposal, String title})> labels = {
  'posture': (title: 'Posture', proposal: false),
};

void main() {
  group('WatchedStudentsCard', () {
    testWidgets('says nobody needs watching without alert', (tester) async {
      await pumpUi(
        tester,
        WatchedStudentsCard(
          watchList: const WatchList(),
          onOpenStudent: (_) {},
          onOpenAll: () {},
        ),
      );

      expect(find.text('To watch'), findsOneWidget);
      expect(find.text('Nobody needs watching'), findsOneWidget);
    });

    testWidgets('lists the student, the exercise, the failures and the level', (
      tester,
    ) async {
      await pumpUi(
        tester,
        WatchedStudentsCard(
          watchList: WatchList(
            lines: [line('Léa', others: 1)],
            total: 1,
            blockLabels: labels,
          ),
          onOpenStudent: (_) {},
          onOpenAll: () {},
        ),
      );

      expect(find.text('Léa'), findsOneWidget);
      expect(find.textContaining('Posture · exercise 1'), findsOneWidget);
      expect(find.textContaining('3 failures in a row'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.textContaining('+ 1 other alert'), findsOneWidget);
    });

    testWidgets('writes the persistent level in words', (tester) async {
      await pumpUi(
        tester,
        WatchedStudentsCard(
          watchList: WatchList(
            lines: [line('Léa', alert: AlertLevel.persistent, failures: 5)],
            total: 1,
            blockLabels: labels,
          ),
          onOpenStudent: (_) {},
          onOpenAll: () {},
        ),
      );

      expect(find.text('Action needed'), findsOneWidget);
    });

    testWidgets('opens a student and the list of all students', (tester) async {
      StudentId? opened;
      var all = 0;
      await pumpUi(
        tester,
        WatchedStudentsCard(
          watchList: WatchList(
            lines: [line('Léa')],
            total: 7,
            blockLabels: labels,
          ),
          onOpenStudent: (id) => opened = id,
          onOpenAll: () => all++,
        ),
      );

      await tester.tap(find.text('Léa'));
      await tester.tap(find.text('See all students (7)'));

      expect(opened, const StudentId('Léa'));
      expect(all, 1);
    });

    testWidgets('has no link to all students when everyone is listed', (
      tester,
    ) async {
      await pumpUi(
        tester,
        WatchedStudentsCard(
          watchList: WatchList(
            lines: [line('Léa')],
            total: 1,
            blockLabels: labels,
          ),
          onOpenStudent: (_) {},
          onOpenAll: () {},
        ),
      );

      expect(find.textContaining('See all students'), findsNothing);
    });
  });

  group('WeekSummaryCard', () {
    testWidgets('counts passes, validations and sessions', (tester) async {
      await pumpUi(
        tester,
        WeekSummaryCard(
          summary: WeekSummary(
            from: DateTime(2026, 10, 6),
            to: DateTime(2026, 10, 12),
            passes: 3,
            validations: 1,
            sessions: 2,
          ),
        ),
      );

      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('3 passes entered'), findsOneWidget);
      expect(find.text('1 exercise validated'), findsOneWidget);
      expect(find.text('2 sessions given'), findsOneWidget);
    });

    testWidgets('says no pass was entered', (tester) async {
      await pumpUi(
        tester,
        WeekSummaryCard(
          summary: WeekSummary(
            from: DateTime(2026, 10, 6),
            to: DateTime(2026, 10, 12),
            passes: 0,
            validations: 0,
            sessions: 0,
          ),
        ),
      );

      expect(find.text('No pass entered in the last 7 days'), findsOneWidget);
    });
  });
}
