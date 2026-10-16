import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the cloth pattern adds nothing for screen readers
///
/// Aucun objet de rendu du motif ne produit de nœud sémantique.
Future<void> theClothPatternAddsNothingForScreenReaders(
  WidgetTester tester,
) async {
  final handle = tester.ensureSemantics();
  await tester.pump();
  final cloth = find.byKey(const ValueKey('presentation-cloth'));
  final nodes = <RenderObject>[];
  void visit(RenderObject object) {
    if (object.debugSemantics != null) nodes.add(object);
    object.visitChildren(visit);
  }

  visit(tester.renderObject(cloth));
  handle.dispose();
  expect(nodes, isEmpty, reason: 'le motif décoratif ne doit pas être annoncé');
}
