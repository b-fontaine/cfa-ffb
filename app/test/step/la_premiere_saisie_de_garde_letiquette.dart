import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laPremiereSaisieDeGardeLetiquette(
  WidgetTester tester,
  String name,
  String tag,
) async {
  final world = OperationsWorld.current;
  final record = world.doc('clubs/c1/records/${world.firstRecord[name]}');
  expect(record, isNotNull);
  expect(record!['tags'], contains(tag));
  expect(world.documentsAbout(name), isEmpty);
}
