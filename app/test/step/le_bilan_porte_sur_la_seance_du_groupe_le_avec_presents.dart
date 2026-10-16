import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le bilan porte sur la séance {'posture-1'} du groupe {'Jeunes'} le
/// {'2026-10-12'} avec {2} présents
Future<void> leBilanPorteSurLaSeanceDuGroupeLeAvecPresents(
  WidgetTester tester,
  String sheet,
  String group,
  String date,
  num present,
) async {
  final review = TrackingWorld.valueOf(TrackingWorld.current.reviewResult);
  expect(review.sheet?.id, SheetId(sheet));
  expect(review.group?.name, group);
  expect(review.record.date, TrackingWorld.date(date));
  expect(review.record.present, hasLength(present.toInt()));
}
