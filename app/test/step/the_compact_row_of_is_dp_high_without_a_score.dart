import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the compact row of {'Léa'} is {48} dp high without a score
///
/// La ligne compacte de l'élève existe (clé propre), mesure exactement
/// [height] dp (la zone tapable des pastilles) plus le remplissage vertical
/// de la ligne (`AppSpacing.xs`, soit xs/2 en haut et en bas), et ses pastilles
/// n'affichent pas le score « x/n ».
Future<void> theCompactRowOfIsDpHighWithoutAScore(
  WidgetTester tester,
  String name,
  num height,
) async {
  final student = await UiWorld.studentNamed(name);
  final card = find.byKey(ValueKey('pass-card-${student.id.value}'));
  final row = find.descendant(
    of: card,
    matching: find.byKey(const ValueKey('student-row-compact')),
  );
  expect(row, findsOneWidget, reason: 'ligne compacte absente');
  expect(
    tester.getSize(row).height,
    height.toDouble() + AppSpacing.xs,
    reason: 'hauteur de la ligne compacte',
  );
  expect(
    find.descendant(
      of: find.descendant(of: row, matching: find.byType(PassDots)),
      matching: find.byType(Text),
    ),
    findsNothing,
    reason: 'score x/n sur les pastilles',
  );
}
