import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall_slot.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/session_sheet_fixtures.dart';

void main() {
  group('SessionSheet invariants', () {
    test('accepts a complete sheet', () {
      final sheet = buildSheet();

      expect(sheet.id, SheetId('demi-bille-1'));
      expect(sheet.exercises, hasLength(2));
    });

    test('accepts the first sheet without previous nor link', () {
      final sheet = buildSheet(
        technique: 'posture',
        order: 1,
        previous: null,
        block: 'posture',
        exercises: [
          sheetExercise('e1', 1, block: 'posture'),
          sheetExercise('e2', 2, block: 'posture'),
        ],
      );

      expect(sheet.previous, isNull);
      expect(sheet.game.link, isNull);
    });

    test('refuses an id that is not <technique>-<part>', () {
      expect(
        () => buildSheet().copyWith(id: SheetId('demi-bille-2')),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a previous sheet on order 1 and none after', () {
      expect(() => buildSheet(order: 1), violation(InvariantCode.invalidSheet));
      expect(
        () => buildSheet(previous: null),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses an exercise of another block', () {
      expect(
        () => buildSheet(
          exercises: [sheetExercise('e1', 1, block: 'quart-finesses')],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses duplicated exercise numbers', () {
      expect(
        () => buildSheet(
          exercises: [sheetExercise('e1', 1), sheetExercise('e2', 1)],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses duplicated local ids', () {
      expect(
        () => buildSheet(theory: [theorySection('t'), theorySection('t')]),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet(
          exercises: [sheetExercise('e', 1), sheetExercise('e', 2)],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses an empty title or notion', () {
      expect(
        () => buildSheet().copyWith(title: ' '),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet().copyWith(notion: ''),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses duplicated initiation ids', () {
      expect(
        () => buildSheet(
          initiation: [sheetInitiation('i'), sheetInitiation('i')],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a link to a previous sheet on the first sheet', () {
      expect(
        () => buildSheet(
          technique: 'posture',
          order: 1,
          previous: null,
          block: 'posture',
          exercises: [
            sheetExercise('e1', 1, block: 'posture'),
            sheetExercise('e2', 2, block: 'posture'),
          ],
          game: sheetGame(
            link: SheetLink(
              notionOf: SheetId('bille-pleine-2'),
              rule: 'Règle.',
              note: 'Note.',
            ),
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a theory without section, or no exercise', () {
      expect(
        () => buildSheet(theory: []),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet(exercises: []),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a game or review without content', () {
      expect(
        () => buildSheet(review: []),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a cited illustration that does not exist', () {
      expect(
        () => buildSheet(
          theory: [
            theorySection('t', illustrations: ['x']),
          ],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('accepts cited illustrations that exist', () {
      final sheet = buildSheet(
        theory: [
          theorySection('t', illustrations: ['c1']),
        ],
        illustrations: [contactIllustration('c1')],
        initiation: [sheetInitiation('i1', illustration: 'c1')],
        game: sheetGame(
          setupIllustration: 'c1',
          link: SheetLink(
            notionOf: SheetId('bille-pleine-2'),
            rule: 'Règle.',
            note: 'Note.',
          ),
        ),
      );

      expect(sheet.illustrations.single.id, 'c1');
    });

    test('refuses two illustrations with the same id', () {
      expect(
        () => buildSheet(
          illustrations: [contactIllustration('c'), contactIllustration('c')],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses an illustration without caption or alternative text', () {
      expect(
        () => buildSheet(
          illustrations: const [
            Illustration.pdfRef(
              id: 'p',
              caption: ' ',
              alt: 'Alt',
              file: 'f.pdf',
              page: 1,
            ),
          ],
        ),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet(
          illustrations: const [
            Illustration.pdfRef(
              id: 'p',
              caption: 'Légende',
              alt: '',
              file: 'f.pdf',
              page: 1,
            ),
          ],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses an adapted game that is not a proposal', () {
      expect(
        () => buildSheet(game: sheetGame(adapted: true)),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('requires a link to the previous sheet from order 2', () {
      expect(
        () => buildSheet(game: sheetGame()),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet(
          game: sheetGame(
            link: SheetLink(
              notionOf: SheetId('autre-1'),
              rule: 'Règle.',
              note: 'Note.',
            ),
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a recall that reuses a sheet other than the previous', () {
      expect(
        () => buildSheet(
          recall: SheetRecall(
            points: const ['Un.', 'Deux.'],
            ask: 'Q ?',
            answer: 'R.',
            reuse: SheetReuse(
              sheet: SheetId('autre-1'),
              illustration: 'contact-plein',
            ),
            src: Provenance.s,
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a sheet whose audience would see no theory', () {
      expect(
        () => buildSheet(
          theory: [theorySection('t', weight: AudienceWeight(adults: 1))],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a game hidden for one audience', () {
      expect(
        () => buildSheet(
          game: sheetGame(
            weight: AudienceWeight(adults: 1),
            link: SheetLink(
              notionOf: SheetId('bille-pleine-2'),
              rule: 'Règle.',
              note: 'Note.',
            ),
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('requires a recall slot from order 2 and refuses one on order 1', () {
      expect(
        () => buildSheet().copyWith(recallSlot: null),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () =>
            buildSheet(
              technique: 'posture',
              order: 1,
              previous: null,
              block: 'posture',
              exercises: [sheetExercise('e1', 1, block: 'posture')],
            ).copyWith(
              recallSlot: SheetRecallSlot(
                weight: AudienceWeight(children: 1, adults: 1),
                passes: 1,
              ),
            ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses a recall slot hidden for an audience or over two passes', () {
      expect(
        () => buildSheet(
          recallSlot: SheetRecallSlot(
            weight: AudienceWeight(children: 1),
            passes: 1,
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
      expect(
        () => buildSheet(
          recallSlot: SheetRecallSlot(
            weight: AudienceWeight(children: 1, adults: 1),
            passes: 3,
          ),
        ),
        violation(InvariantCode.invalidSheet),
      );
    });

    test('refuses more than two passes on an exercise', () {
      expect(
        () => buildSheet(
          exercises: [
            sheetExercise('e1', 1, passes: 3),
            sheetExercise('e2', 2),
          ],
        ),
        violation(InvariantCode.invalidSheet),
      );
    });
  });

  group('AudienceWeight', () {
    test('reads the weight of each audience', () {
      final weight = AudienceWeight(children: 3, adults: 2);

      expect(weight.of(Audience.children), 3);
      expect(weight.of(Audience.adults), 2);
    });

    test('hides the element for an audience without weight', () {
      final weight = AudienceWeight(adults: 2);

      expect(weight.isShownFor(Audience.children), isFalse);
      expect(weight.isShownFor(Audience.adults), isTrue);
    });

    test('refuses a weight below 1 and an element shown for nobody', () {
      expect(
        () => AudienceWeight(children: 0),
        violation(InvariantCode.invalidSheet),
      );
      expect(AudienceWeight.new, violation(InvariantCode.invalidSheet));
    });
  });

  group('Provenance', () {
    test('only Prop is a proposal', () {
      expect(Provenance.prop.isProposal, isTrue);
      expect(
        [Provenance.s, Provenance.ffb, Provenance.web].any((s) => s.isProposal),
        isFalse,
      );
    });
  });
}
