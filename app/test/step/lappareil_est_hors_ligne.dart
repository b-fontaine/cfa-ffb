import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> lappareilEstHorsLigne(WidgetTester tester) async {
  OwnMarkersWorld.current.server.failing = StoreFailureCode.unavailable;
}
