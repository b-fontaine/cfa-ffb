import 'package:billard_cfa/pages/record_session/presentation/record_session_page.dart';
import 'package:billard_cfa/pages/record_setup/presentation/record_setup_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the record sheet is open
///
/// La feuille est présente, héberge l'ouverture ou la saisie d'une séance et
/// occupe la hauteur prévue (92 % de l'écran, zones sûres comprises).
Future<void> theRecordSheetIsOpen(WidgetTester tester) async {
  final sheet = find.byKey(const ValueKey('record-sheet'));
  expect(sheet, findsOneWidget);
  expect(
    find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate(
        (w) => w is RecordSetupPage || w is RecordSessionPage,
      ),
    ),
    findsOneWidget,
    reason: "la feuille n'héberge ni l'ouverture ni la saisie",
  );
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(tester.getSize(sheet).height, closeTo(screen * 0.92, 1));
}
