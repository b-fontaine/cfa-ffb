import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pdf_preview.dart';
import '../support/ui_world.dart';

/// Usage: the PDF preview has {2} pages for each exercise of
/// {'demi-bille-1'} in the audience {'children'}
Future<void> thePdfPreviewHasPagesForEachExerciseOfInTheAudience(
  WidgetTester tester,
  int pagesPerExercise,
  String sheet,
  String audience,
) async {
  final shown = UiWorld.audience(audience);
  final found = await tester.runAsync(
    () => getIt<SessionSheetRepository>().getById(SheetId(sheet)),
  );
  final exercises = found!.exercises
      .where((exercise) => exercise.weight.isShownFor(shown))
      .length;
  expect(previewDocument(tester).pages.length, pagesPerExercise * exercises);
}
