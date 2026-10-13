import 'package:billard_cfa/shared/ui/pdf_page_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('writes the page and the file name, in French', (tester) async {
    await pumpUi(
      tester,
      const PdfPageChip(file: 'Fiches techniques CFA BàP.pdf', page: 15),
      locale: const Locale('fr'),
    );

    expect(find.text('Voir la page 15 du PDF'), findsOneWidget);
    expect(find.text('Fiches techniques CFA BàP.pdf'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Voir la page 15 du PDF (Fiches techniques CFA BàP.pdf)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('writes the English sentence', (tester) async {
    await pumpUi(tester, const PdfPageChip(file: 'a.pdf', page: 3));

    expect(find.text('See page 3 of the PDF'), findsOneWidget);
    expect(
      find.bySemanticsLabel('See page 3 of the PDF (a.pdf)'),
      findsOneWidget,
    );
  });

  testWidgets('is text only: no image and nothing to tap', (tester) async {
    await pumpUi(tester, const PdfPageChip(file: 'a.pdf', page: 3));

    expect(find.byType(Image), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('does not overflow with a long file name on a narrow width', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 120,
          child: PdfPageChip(
            file: 'Un nom de fichier vraiment très très long.pdf',
            page: 12,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
