import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leMarqueurDeClotureRetrouveLaSaisonLeJourEtLesDeuxChoixDuDirecteur(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  world.store.failAfterBatches = null;
  final terms = switch (await world.closing.pending()) {
    Ok(:final value) => value,
    final other => fail('lecture du marqueur refusée : $other'),
  };
  expect(terms, isNotNull);
  expect(terms!.seasonId, OperationsWorld.seasonId);
  expect(terms.closedOn, OperationsWorld.day);
  expect(terms.prepareNext, isTrue);
  expect(terms.dropPlanned, isTrue);
}
