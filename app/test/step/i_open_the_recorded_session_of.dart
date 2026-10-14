import 'package:billard_cfa/features/record_results/presentation/ui/recorded_session_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the recorded session of {'Sep 12'}
///
/// Appuie sur la ligne de l'historique dont la date contient [date] ; une
/// seule ligne doit correspondre.
Future<void> iOpenTheRecordedSessionOf(WidgetTester tester, String date) async {
  final row = find.descendant(
    of: find.byType(RecordedSessionList),
    matching: find.textContaining(date),
  );
  expect(row, findsOneWidget, reason: 'séance du $date introuvable ou ambiguë');
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}
