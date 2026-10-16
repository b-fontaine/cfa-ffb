import 'package:billard_cfa/features/student_showcase/presentation/ui/showcase_view.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/features/track_group/domain/list_group_alerts.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_alerts_card.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_attendance_card.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_heat_map.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_text_summary.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/student_sheet_view.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/sheet_world.dart';
import '../../../shared/ui/pump_ui.dart';

/// Les écrans du lot U9 sur un téléphone étroit (320 dp) et avec le texte à
/// 200 % : aucun débordement (un `RenderFlex overflowed` ferait échouer le
/// test) et rien d'illisible.
void main() {
  late SheetWorld world;

  setUp(() async {
    world = SheetWorld();
    await world.start(students: ['s1', 's2', 's3']);
    await world.passes(ref('a', 1), 5);
    await world.passes(ref('a', 2), 3, pass: false);
    await world.passes(ref('b', 1), 3, pass: false, student: 's2');
    await world.acquire('c');
  });

  void narrow(WidgetTester tester, {double textScale = 2}) {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  for (final scale in [1.0, 2.0]) {
    group('at ${scale * 100} % text on 320 dp', () {
      testWidgets('the student sheet does not overflow', (tester) async {
        narrow(tester, textScale: scale);
        final sheet = await world.sheet(tester);
        await pumpUi(
          tester,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: StudentSheetView(
              sheet: sheet,
              onAcknowledge: (_) {},
              onRestore: (_) {},
              onMarkAcquired: (_) {},
              onRevokeAcquired: (_) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('path-list')), findsOneWidget);
      });

      testWidgets('the showcase does not overflow', (tester) async {
        narrow(tester, textScale: scale);
        final showcase = await world.showcase(tester);
        await pumpUi(
          tester,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ShowcaseView(showcase: showcase),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('the group view does not overflow', (tester) async {
        narrow(tester, textScale: scale);
        final grid = await world.grid(tester);
        await pumpUi(
          tester,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GroupAttendanceCard(attendance: grid.attendance),
                GroupHeatMap(grid: grid, onOpenStudent: (_) {}),
                GroupTextSummary(grid: grid),
                GroupAlertsCard(
                  alerts: const GroupAlertList(
                    lines: [
                      GroupAlertLine(
                        groupId: GroupId('g1'),
                        groupName: 'Un groupe au nom assez long',
                        alert: GroupAlert(
                          blockId: 'a',
                          blockTitle: 'Posture, visée et coup de queue',
                          failed: 4,
                          members: 8,
                        ),
                      ),
                    ],
                    total: 1,
                  ),
                  onOpenGroup: (_) {},
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('heat-scroll')), findsOneWidget);
      });
    });
  }
}
