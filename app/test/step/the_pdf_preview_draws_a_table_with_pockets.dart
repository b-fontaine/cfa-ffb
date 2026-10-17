import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';

/// Usage: the PDF preview draws a table with {6} pockets
///
/// Chaque table dessinée a exactement [pockets] poches (cercles repérés
/// `pocket`), et il y a au moins une table.
Future<void> thePdfPreviewDrawsATableWithPockets(
  WidgetTester tester,
  int pockets,
) async {
  final items = previewItems(tester).toList();
  final tables = items.whereType<PrintRect>().where((r) => r.tag == 'table');
  final found = items.whereType<PrintCircle>().where((c) => c.tag == 'pocket');
  expect(tables, isNotEmpty, reason: 'aucune table dessinée');
  expect(found.length, pockets * tables.length);
}
