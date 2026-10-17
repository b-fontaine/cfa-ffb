import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview letters every ball
///
/// Chaque bille dessinée (cercle repéré `ball`) porte sa lettre (R, J, N ou B)
/// : la couleur ne porte jamais seule le sens.
Future<void> thePdfPreviewLettersEveryBall(WidgetTester tester) async {
  final items = previewItems(tester).toList();
  final circles = items.whereType<PrintCircle>().where((i) => i.tag == 'ball');
  final letters = items
      .whereType<PrintText>()
      .where((i) => i.tag == 'ball-letter')
      .toList();
  expect(circles, isNotEmpty, reason: 'aucune bille dessinée');
  expect(letters.length, circles.length);
  expect(
    letters.map((l) => l.text).toSet(),
    everyElement(isIn({'R', 'J', 'N', 'B'})),
  );
}
