import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

ShowcaseRow _showcaseRow(String blockTitleKey) {
  final catalogue = TrackingWorld.current.catalogue;
  final block = catalogue.blockById(blockTitleKey)!;
  return TrackingWorld.current.showcase.rows.firstWhere(
    (row) => row.title == block.title,
  );
}

const Map<String, ShowcaseRowStatus> _rowStatuses = {
  'à commencer': ShowcaseRowStatus.todo,
  'en cours': ShowcaseRowStatus.inProgress,
  'terminée': ShowcaseRowStatus.finished,
  'acquise': ShowcaseRowStatus.acquired,
};

/// Usage: la technique {'posture'} de la vue élève est {'acquise'}
Future<void> laTechniqueDeLaVueEleveEst(
  WidgetTester tester,
  String block,
  String status,
) async {
  expect(_showcaseRow(block).status, _rowStatuses[status]);
}
