import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_game.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_recall.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/session_sheet_fixtures.dart';

SheetLink _link() => SheetLink(
  notionOf: SheetId('bille-pleine-2'),
  rule: 'Règle.',
  note: 'Note.',
);

void main() {
  test('a fully sourced sheet needs no review', () {
    final sheet = buildSheet(previous: null, order: 1);

    expect(reviewReasonsOf(sheet), isEmpty);
    expect(needsReview(sheet), isFalse);
    expect(gameNeedsReview(sheet), isFalse);
  });

  test('a link rule on a federal game is signalled, not counted', () {
    final sheet = buildSheet(game: sheetGame(link: _link()));

    expect(reviewReasonsOf(sheet), {ReviewReason.gameLink});
    expect(ReviewReason.gameLink.counts, isFalse);
    expect(needsReview(sheet), isFalse);
    expect(gameNeedsReview(sheet), isFalse);
  });

  test('an adapted game with a link is one reason, the game', () {
    final sheet = buildSheet(
      game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
    );

    expect(reviewReasonsOf(sheet), {ReviewReason.game});
    expect(gameNeedsReview(sheet), isTrue);
  });

  test('a child-only gloss is not a reason, an adult section is', () {
    final gloss = buildSheet(
      theory: [
        theorySection('t1'),
        theorySection(
          'mot',
          src: Provenance.prop,
          weight: AudienceWeight(children: 1),
        ),
      ],
    );
    final shared = buildSheet(
      theory: [theorySection('t1', src: Provenance.prop)],
    );

    expect(reviewReasonsOf(gloss).contains(ReviewReason.theory), isFalse);
    expect(reviewReasonsOf(shared), contains(ReviewReason.theory));
    expect(needsReview(shared), isFalse);
  });

  test('exercise, initiation and recall proposals each name their reason', () {
    expect(
      reviewReasonsOf(
        buildSheet(exercises: [sheetExercise('e1', 1, src: Provenance.prop)]),
      ),
      contains(ReviewReason.exercise),
    );
    expect(
      reviewReasonsOf(
        buildSheet(initiation: [sheetInitiation('i', src: Provenance.prop)]),
      ),
      contains(ReviewReason.initiation),
    );
    expect(
      reviewReasonsOf(
        buildSheet(
          recall: const SheetRecall(
            points: ['Un.', 'Deux.'],
            ask: 'Q ?',
            answer: 'R.',
            src: Provenance.prop,
          ),
        ),
      ),
      contains(ReviewReason.recall),
    );
  });

  test('theme, challenges, variant and link alone do not trigger it', () {
    // Le thème, les défis (`playful`), `playful_variant` et `link_previous`
    // sont [Prop] sur toute séance : ils ne comptent pas (FORMAT § 5.3).
    final sheet = buildSheet(game: sheetGame(link: _link()));

    expect(sheet.game.playfulVariant, isNotEmpty);
    expect(sheet.exercises.first.playful.challenge, isNotEmpty);
    expect(needsReview(sheet), isFalse);
  });

  test('an adapted game triggers it', () {
    final sheet = buildSheet(
      game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
    );

    expect(needsReview(sheet), isTrue);
  });

  test('a game without source triggers it', () {
    final sheet = buildSheet(
      game: sheetGame(sourceGame: null, src: Provenance.prop, link: _link()),
    );

    expect(needsReview(sheet), isTrue);
  });

  test('a proposal exercise triggers it', () {
    final sheet = buildSheet(
      exercises: [
        sheetExercise('e1', 1, src: Provenance.prop),
        sheetExercise('e2', 2, src: Provenance.prop),
      ],
    );

    expect(needsReview(sheet), isTrue);
  });

  test('a proposal recall triggers it', () {
    final sheet = buildSheet(
      recall: const SheetRecall(
        points: ['Un.', 'Deux.'],
        ask: 'Q ?',
        answer: 'R.',
        src: Provenance.prop,
      ),
    );

    expect(needsReview(sheet), isTrue);
  });

  test('a proposal initiation triggers it', () {
    final sheet = buildSheet(
      initiation: [sheetInitiation('i', src: Provenance.prop)],
    );

    expect(needsReview(sheet), isTrue);
  });

  group('a single proposal among sourced elements', () {
    test('one proposal exercise among sourced ones triggers it', () {
      final sheet = buildSheet(
        exercises: [
          sheetExercise('e1', 1),
          sheetExercise('e2', 2, src: Provenance.prop),
        ],
      );

      expect(needsReview(sheet), isTrue);
    });

    test('one proposal initiation among sourced ones triggers it', () {
      final sheet = buildSheet(
        initiation: [
          sheetInitiation('i1'),
          sheetInitiation('i2', src: Provenance.prop),
        ],
      );

      expect(needsReview(sheet), isTrue);
    });

    test('a game with a source and not adapted, but src Prop, triggers it', () {
      final sheet = buildSheet(
        game: sheetGame(src: Provenance.prop, link: _link()),
      );

      expect(sheet.game.adapted, isFalse);
      expect(sheet.game.sourceGame, isNotNull);
      expect(needsReview(sheet), isTrue);
    });

    test('a sourced game with no source game number triggers it', () {
      final sheet = buildSheet(
        game: sheetGame(sourceGame: null, link: _link()),
      );

      expect(sheet.game.src, Provenance.s);
      expect(needsReview(sheet), isTrue);
    });
  });

  group('reviewPointCount', () {
    test('is zero for a fully sourced sheet', () {
      expect(reviewPointCount(buildSheet(previous: null, order: 1)), 0);
    });

    test('counts each content type to review once, not each block', () {
      final sheet = buildSheet(
        exercises: [
          sheetExercise('e1', 1, src: Provenance.prop),
          sheetExercise('e2', 2, src: Provenance.prop),
        ],
        game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
      );

      expect(reviewPointCount(sheet), 2);
    });

    test('is exactly one for one content type and three for three', () {
      final one = buildSheet(
        exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
      );
      final three = buildSheet(
        exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
        initiation: [sheetInitiation('i', src: Provenance.prop)],
        game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
      );

      expect(reviewPointCount(one), 1);
      expect(reviewPointCount(three), 3);
    });

    test('counts the four reasons that matter, at most four', () {
      final sheet = buildSheet(
        exercises: [sheetExercise('e1', 1, src: Provenance.prop)],
        initiation: [sheetInitiation('i', src: Provenance.prop)],
        recall: const SheetRecall(
          points: ['Un.', 'Deux.'],
          ask: 'Q ?',
          answer: 'R.',
          src: Provenance.prop,
        ),
        game: sheetGame(adapted: true, src: Provenance.prop, link: _link()),
      );

      expect(reviewPointCount(sheet), 4);
    });

    test('does not count the signalled proposals (link rule, theory)', () {
      final sheet = buildSheet(
        game: sheetGame(link: _link()),
        theory: [theorySection('t1', src: Provenance.prop)],
      );

      expect(reviewReasonsOf(sheet), {
        ReviewReason.gameLink,
        ReviewReason.theory,
      });
      expect(reviewPointCount(sheet), 0);
    });

    test('is positive exactly when the sheet needs review, on the 28 real '
        'sheets', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final sheets = await AssetSessionSheetRepository.fromBundle().getAll();

      expect(sheets, hasLength(28));
      for (final sheet in sheets) {
        expect(
          reviewPointCount(sheet) > 0,
          needsReview(sheet),
          reason: sheet.id.value,
        );
      }
      expect(sheets.where(needsReview), hasLength(18));
    });
  });
}
