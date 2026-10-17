import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_preview_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le document que l'aperçu montre : la même scène que celle du PDF.
PrintDocument previewDocument(WidgetTester tester) {
  final finder = find.byKey(printPreviewKey);
  expect(finder, findsOneWidget, reason: "l'aperçu du PDF est absent");
  return tester.widget<PrintPreviewView>(finder).document;
}

/// Tous les éléments de toutes les pages, dans l'ordre de lecture.
Iterable<PrintItem> previewItems(WidgetTester tester) =>
    previewDocument(tester).pages.expand((page) => page.items);

/// Tous les textes de toutes les pages, un par ligne.
List<String> previewLines(WidgetTester tester) => [
  for (final item in previewItems(tester))
    if (item is PrintText) item.text,
];

/// Le texte de l'aperçu sur une seule ligne, espaces normalisés (une phrase
/// coupée en deux lignes reste trouvable).
String previewText(WidgetTester tester) =>
    previewLines(tester).join(' ').replaceAll(RegExp(r'\s+'), ' ');
