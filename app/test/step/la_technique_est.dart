import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/features/track_progress/domain/path_row.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

PathRow _row(String blockId) => TrackingWorld.current.sheet.path.firstWhere(
  (row) => row.blockId == blockId,
  orElse: () => fail('technique inconnue : $blockId'),
);

const Map<String, BlockStatus> _blockStatuses = {
  'à commencer': BlockStatus.notStarted,
  'en cours': BlockStatus.inProgress,
  'terminée': BlockStatus.mastered,
  'acquise au positionnement': BlockStatus.acquiredAtPlacement,
  'à revoir': BlockStatus.toReview,
};

/// Usage: la technique {'posture'} est {'à revoir'}
Future<void> laTechniqueEst(
  WidgetTester tester,
  String block,
  String status,
) async {
  expect(_row(block).summary.status, _blockStatuses[status]);
}
