import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_alerts_card.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_alerts_list.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_attendance_card.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_heat_map.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_text_summary.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/sheet_world.dart';
import '../../../shared/ui/pump_ui.dart';

void main() {
  late SheetWorld world;

  setUp(() async {
    world = SheetWorld();
    await world.start(students: ['s1', 's2']);
  });

  Future<GroupGrid> grid(WidgetTester tester) => world.grid(tester);

  group('GroupHeatMap', () {
    Future<void> pump(
      WidgetTester tester,
      GroupGrid grid, {
      ValueChanged<StudentId>? onOpenStudent,
    }) => pumpUi(
      tester,
      SingleChildScrollView(
        child: GroupHeatMap(grid: grid, onOpenStudent: onOpenStudent ?? (_) {}),
      ),
    );

    testWidgets('crosses the techniques with the students', (tester) async {
      await pump(tester, await grid(tester));

      for (final block in ['a', 'b', 'c']) {
        expect(find.byKey(ValueKey('heat-row-$block')), findsOneWidget);
        expect(find.text('Bloc $block'), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('heat-column-s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-column-s2')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-cell-a-s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-cell-c-s2')), findsOneWidget);
    });

    testWidgets('writes a fraction in every cell', (tester) async {
      await world.passes(ref('a', 1), 5);
      await world.passes(ref('a', 2), 5);
      await pump(tester, await grid(tester));

      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('0/3'), findsNWidgets(5));
    });

    testWidgets('describes each cell as text, with its alert', (tester) async {
      final semantics = tester.ensureSemantics();
      await world.passes(ref('a', 1), 5);
      await world.passes(ref('b', 1), 3, pass: false, student: 's2');
      await pump(tester, await grid(tester));

      expect(
        find.bySemanticsLabel('s1, Bloc a: 1 of 3 exercises, In progress'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('s2, Bloc a: 0 of 3 exercises, Not started'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          's2, Bloc b: 0 of 3 exercises, To review, alert in progress',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('heat-marker-alert')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('summarises each row as text', (tester) async {
      final semantics = tester.ensureSemantics();
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await world.passes(ref('b', 1), 1, student: 's2');
      await pump(tester, await grid(tester));

      expect(
        find.bySemanticsLabel(
          'Bloc a: 1 of 2 students completed, 0 in progress, 1 to start',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Bloc b: 0 of 2 students completed, 1 in progress, 1 to start',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a completed technique has a tick, an acquired one a flag', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await world.acquire('b');
      await pump(tester, await grid(tester));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added), findsOneWidget);
    });

    testWidgets('a cell and a header open the student', (tester) async {
      final opened = <StudentId>[];
      await pump(tester, await grid(tester), onOpenStudent: opened.add);

      await tester.tap(find.byKey(const ValueKey('heat-cell-a-s2')));
      await tester.tap(find.byKey(const ValueKey('heat-column-s1')));

      expect(opened, [const StudentId('s2'), const StudentId('s1')]);
    });

    testWidgets('adds the attendance of each student below the grid', (
      tester,
    ) async {
      await pump(tester, await grid(tester));

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('1/1'), findsNWidgets(2));
    });

    testWidgets('says so when no student is in the group today', (
      tester,
    ) async {
      final empty = (await grid(tester)).copyWith(students: [], rows: []);
      await pump(tester, empty);

      expect(find.text('No student in this group today.'), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-scroll')), findsNothing);
    });

    testWidgets('explains the symbols of the grid in text', (tester) async {
      await pump(tester, await grid(tester));

      expect(find.textContaining('A tick means'), findsOneWidget);
    });
  });

  group('GroupTextSummary', () {
    testWidgets('is folded by default and lists the students by state', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await world.passes(ref('b', 1), 1, student: 's2');
      final value = await grid(tester);
      await pumpUi(
        tester,
        SingleChildScrollView(child: GroupTextSummary(grid: value)),
      );

      expect(find.text('Text summary'), findsOneWidget);
      expect(find.textContaining('Completed:'), findsNothing);

      await tester.tap(find.text('Text summary'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bloc a. Completed: s1. In progress: nobody. To start: s2.'),
        findsOneWidget,
      );
      expect(
        find.text('Bloc b. Completed: nobody. In progress: s2. To start: s1.'),
        findsOneWidget,
      );
    });
  });

  group('GroupAttendanceCard', () {
    testWidgets('counts the present members over the possible ones', (
      tester,
    ) async {
      await world.world.session(id: 'x2', dayOfMonth: 5, present: {'s1'});
      final value = await grid(tester);
      await pumpUi(tester, GroupAttendanceCard(attendance: value.attendance));

      expect(find.text('Group attendance'), findsOneWidget);
      expect(
        find.text('3 attendances out of 4 possible (75 %)'),
        findsOneWidget,
      );
      expect(find.text('2 sessions'), findsOneWidget);
      expect(find.text('Mon, Oct 5: 1 of 2 present'), findsOneWidget);
      expect(find.text('Fri, Oct 2: 2 of 2 present'), findsOneWidget);
    });

    testWidgets('a group without session says so instead of zero percent', (
      tester,
    ) async {
      final fresh = SheetWorld();
      await fresh.world.seedClub(studentNames: ['s1']);
      final value = await fresh.grid(tester);
      await pumpUi(tester, GroupAttendanceCard(attendance: value.attendance));

      expect(find.text('No session recorded yet.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('GroupAlertsList', () {
    testWidgets('states how many students missed a technique', (tester) async {
      await pumpUi(
        tester,
        const GroupAlertsList(
          alerts: [
            GroupAlert(
              blockId: 'a',
              blockTitle: 'Bloc a',
              failed: 4,
              members: 8,
            ),
          ],
        ),
      );

      expect(find.text('Group alerts'), findsOneWidget);
      expect(
        find.text('4 students out of 8 missed “Bloc a” on their last pass'),
        findsOneWidget,
      );
    });

    testWidgets('shows nothing without alert', (tester) async {
      await pumpUi(tester, const GroupAlertsList(alerts: []));

      expect(find.text('Group alerts'), findsNothing);
    });
  });

  group('GroupAlertsCard', () {
    GroupAlertLine line(String group, String id, int failed) => GroupAlertLine(
      groupId: GroupId(id),
      groupName: group,
      alert: GroupAlert(
        blockId: 'a',
        blockTitle: 'Bloc a',
        failed: failed,
        members: 8,
      ),
    );

    testWidgets('lists the group, the alert and opens the grid', (
      tester,
    ) async {
      GroupId? opened;
      await pumpUi(
        tester,
        GroupAlertsCard(
          alerts: GroupAlertList(lines: [line('Jeunes', 'g1', 4)], total: 1),
          onOpenGroup: (id) => opened = id,
        ),
      );

      expect(find.text('Group alerts'), findsOneWidget);
      expect(find.text('Jeunes'), findsOneWidget);
      expect(
        find.text('4 students out of 8 missed “Bloc a” on their last pass'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('group-alert-0')), findsOneWidget);
      final size = tester.getSize(find.byKey(const ValueKey('group-alert-0')));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const ValueKey('group-alert-0')));
      expect(opened, const GroupId('g1'));
    });

    testWidgets('counts the alerts it does not list', (tester) async {
      await pumpUi(
        tester,
        GroupAlertsCard(
          alerts: GroupAlertList(
            lines: [line('Jeunes', 'g1', 4), line('Adultes', 'g2', 3)],
            total: 3,
          ),
          onOpenGroup: (_) {},
        ),
      );

      expect(find.byKey(const ValueKey('group-alert-1')), findsOneWidget);
      expect(find.text('+ 1 other group alert'), findsOneWidget);
    });

    testWidgets('is named as a button for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        GroupAlertsCard(
          alerts: GroupAlertList(lines: [line('Jeunes', 'g1', 4)], total: 1),
          onOpenGroup: (_) {},
        ),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('group-alert-0')),
      );
      expect(
        node.label,
        'Open the grid of Jeunes: 4 students out of 8 missed “Bloc a” on '
        'their last pass',
      );
      expect(node.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('shows nothing without group alert', (tester) async {
      await pumpUi(
        tester,
        GroupAlertsCard(alerts: const GroupAlertList(), onOpenGroup: (_) {}),
      );

      expect(find.text('Group alerts'), findsNothing);
    });
  });
}
