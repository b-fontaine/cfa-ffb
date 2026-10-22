import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leDirecteurClotLaSaisonEnEffacantUnEleveInconnu(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current
    ..toErase = {const StudentId('s-inconnu')};
  await world.close();
}
