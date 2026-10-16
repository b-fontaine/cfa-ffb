import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

GridRow _gridRow(String blockId) => TrackingWorld.current.grid.rows.firstWhere(
  (row) => row.technique.blockId == blockId,
  orElse: () => fail('technique inconnue : $blockId'),
);

/// Usage: les élèves à commencer sur la technique {'posture'} sont {'Hugo'}
Future<void> lesElevesACommencerSurLaTechniqueSont(
  WidgetTester tester,
  String block,
  String students,
) async {
  expect(_gridRow(block).toStart, [
    for (final name in TrackingWorld.names(students))
      TrackingWorld.studentId(name),
  ]);
}
