import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> laPurgeEstRefusee(WidgetTester tester) async {
  final result = StaleMarkersWorld.current.result;
  expect(result?.status, StaleMarkerPurgeStatus.failed);
  expect(result?.failure?.code, ServiceFailureCode.denied);
  expect(result?.removed, 0);
}
