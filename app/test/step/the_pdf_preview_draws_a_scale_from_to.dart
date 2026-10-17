import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview draws a scale from {0} to {16}
///
/// L'axe de la grille fédérale : un repère `scale-label` par graduation, de
/// [from] à [to] inclus.
Future<void> thePdfPreviewDrawsAScaleFromTo(
  WidgetTester tester,
  int from,
  int to,
) async {
  final ticks = previewItems(tester)
      .whereType<PrintText>()
      .where((t) => t.tag == 'scale-label')
      .map((t) => t.text)
      .toSet();
  expect(ticks, {for (var n = from; n <= to; n++) '$n'});
}
