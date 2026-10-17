import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview draws no image
///
/// Deux garanties. La scène d'impression ne sait dessiner que du texte, des
/// traits et des formes : un élément d'un autre type ferait échouer la
/// compilation du `switch` ci-dessous (garantie de la classe scellée, sans
/// assertion à l'exécution). Et l'aperçu à l'écran ne contient aucun widget
/// `Image`.
Future<void> thePdfPreviewDrawsNoImage(WidgetTester tester) async {
  final items = previewItems(tester).toList();
  expect(items, isNotEmpty);
  for (final item in items) {
    switch (item) {
      case PrintText():
      case PrintLine():
      case PrintPolyline():
      case PrintRect():
      case PrintCircle():
      case PrintPolygon():
        break;
    }
  }
  expect(find.byType(Image), findsNothing);
}
