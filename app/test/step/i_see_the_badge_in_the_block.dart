import 'package:billard_cfa/features/track_progress/presentation/ui/block_progress_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the badge {'Proposal'} in the block {'Posture'}
///
/// La pastille est un descendant de la ligne du bloc (la colonne qui porte
/// son titre), pas un nombre d'occurrences dépendant du catalogue.
Future<void> iSeeTheBadgeInTheBlock(
  WidgetTester tester,
  String badge,
  String block,
) async {
  final title = find.descendant(
    of: find.byType(BlockProgressList),
    matching: find.text(block),
  );
  expect(title, findsOneWidget);
  final row = find.ancestor(of: title, matching: find.byType(Column)).first;
  expect(find.descendant(of: row, matching: find.text(badge)), findsOneWidget);
}
