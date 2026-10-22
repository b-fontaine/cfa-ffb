import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurClotANouveauLaSaison(WidgetTester tester) async {
  await OperationsWorld.current.close();
}
