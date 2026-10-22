import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// Usage: le compte du parent n'est lié qu'à {'Tom'}
Future<void> leCompteDuParentNestLieQua(
  WidgetTester tester,
  String name,
) async {
  final member = OperationsWorld.current.doc('clubs/c1/members/u-parent');
  expect(
    member,
    isNotNull,
    reason: 'le compte reste : un enfant lui reste lié',
  );
  expect(member!['studentIds'], [OperationsWorld.idOf(name)]);
}
