import 'dart:ui' show Locale;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('writes the block and the exercise number', () {
    expect(
      exerciseTitle(en, blockTitle: 'Power', number: 2),
      'Power · exercise 2',
    );
  });

  test('tags a proposal, never a federal exercise', () {
    expect(
      exerciseTitle(en, blockTitle: 'Posture', number: 1, proposal: true),
      'Posture · exercise 1 · Proposal',
    );
    expect(
      exerciseTitle(fr, blockTitle: 'Posture', number: 1, proposal: true),
      'Posture · exercice 1 · Proposition',
    );
    expect(
      exerciseTitle(fr, blockTitle: 'Posture', number: 1),
      'Posture · exercice 1',
    );
  });
}
