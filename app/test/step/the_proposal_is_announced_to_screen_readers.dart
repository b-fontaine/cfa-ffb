import 'package:flutter_test/flutter_test.dart';

/// Usage: the proposal is announced to screen readers
///
/// En mode Mener les badges sont masqués, mais l'information `[Prop]` reste
/// dans l'arbre sémantique.
Future<void> theProposalIsAnnouncedToScreenReaders(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  expect(find.bySemanticsLabel('Proposal'), findsWidgets);
  semantics.dispose();
}
