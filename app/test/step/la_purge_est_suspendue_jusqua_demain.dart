import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> laPurgeEstSuspendueJusquaDemain(WidgetTester tester) async {
  expect(
    StaleMarkersWorld.current.result?.status,
    StaleMarkerPurgeStatus.paused,
  );
}
