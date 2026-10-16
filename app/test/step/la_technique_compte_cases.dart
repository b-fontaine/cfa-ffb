import 'package:billard_cfa/features/track_progress/domain/path_row.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

PathRow _row(String blockId) => TrackingWorld.current.sheet.path.firstWhere(
  (row) => row.blockId == blockId,
  orElse: () => fail('technique inconnue : $blockId'),
);

/// Usage: la technique {'posture'} compte {4} cases
Future<void> laTechniqueCompteCases(
  WidgetTester tester,
  String block,
  num count,
) async {
  expect(_row(block).summary.cells, hasLength(count.toInt()));
}
