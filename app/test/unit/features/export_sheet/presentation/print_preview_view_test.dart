import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_preview_view.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

PrintDocument _document() => const PrintDocument(
  title: 'Titre',
  language: 'fr',
  pages: [
    PrintPage(width: 100, height: 200, items: []),
    PrintPage(
      width: 200,
      height: 100,
      items: [PrintText(x: 1, y: 8, text: 'Deuxième', size: 8)],
    ),
  ],
);

void main() {
  Future<void> pump(WidgetTester tester, int page) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(tester, PrintPreviewView(document: _document(), page: page));
  }

  testWidgets('is found by its key and exposes its document', (tester) async {
    await pump(tester, 0);

    final view = tester.widget<PrintPreviewView>(find.byKey(printPreviewKey));
    expect(view.document.pages, hasLength(2));
  });

  testWidgets('names the page for a screen reader', (tester) async {
    await pump(tester, 1);

    expect(find.bySemanticsLabel('PDF preview, page 2 of 2'), findsOneWidget);
  });

  testWidgets('keeps the proportions of the page it shows', (tester) async {
    await pump(tester, 0);
    final portrait = tester.getSize(find.byType(AspectRatio));
    await pump(tester, 1);
    final landscape = tester.getSize(find.byType(AspectRatio));

    expect(portrait.height / portrait.width, closeTo(2, 1e-9));
    expect(landscape.width / landscape.height, closeTo(2, 1e-9));
  });

  testWidgets('limits the width of the sheet', (tester) async {
    await pump(tester, 1);

    expect(tester.getSize(find.byType(AspectRatio)).width, 520);
  });

  testWidgets('shows the last page for a page beyond the document', (
    tester,
  ) async {
    await pump(tester, 9);

    expect(find.bySemanticsLabel('PDF preview, page 2 of 2'), findsOneWidget);
  });

  testWidgets('shows the first page for a negative page', (tester) async {
    await pump(tester, -3);

    expect(find.bySemanticsLabel('PDF preview, page 1 of 2'), findsOneWidget);
  });

  testWidgets('paints the page on a white sheet', (tester) async {
    await pump(tester, 1);

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PrintScenePainter,
      ),
    );
    expect((paint.painter! as PrintScenePainter).page.width, 200);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PrintPreviewView),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, Colors.white);
  });
}
